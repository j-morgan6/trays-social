defmodule TraysSocialWeb.PostLive.NewRecipeFirstTest do
  # async: false: toggles the global :features config.
  use TraysSocialWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures

  alias TraysSocial.Posts.Post
  alias TraysSocial.Repo
  alias TraysSocial.Uploads.Photo

  # Smallest JPEG the upload's magic-byte check accepts.
  @tiny_jpeg <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00,
               0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9>>

  setup %{conn: conn} do
    original = Application.get_env(:trays_social, :features, [])
    Application.put_env(:trays_social, :features, Keyword.put(original, :recipe_first, true))
    on_exit(fn -> Application.put_env(:trays_social, :features, original) end)
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  # D126: the preview title keeps an abbreviation's period, as every other
  # surface does, and a caption with no title keeps the placeholder.
  test "the preview titles Mrs. Smith's pie in full", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/posts/new")

    view
    |> form("#post-form", post: %{caption: "Mrs. Smith's pie. Flaky crust."})
    |> render_change()

    assert has_element?(view, "#editor-preview", "Mrs. Smith's pie")
    refute has_element?(view, "#editor-preview", "Flaky crust")

    view |> form("#post-form", post: %{caption: "..."}) |> render_change()

    assert has_element?(view, "#editor-preview", "Your recipe name")
  end

  test "opens straight on the recipe form", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/posts/new")

    refute html =~ "What are you sharing?"
    refute html =~ "Share a post"
    assert has_element?(view, "#editor-publish button[type=submit]", "Post recipe")
    refute has_element?(view, ~s([phx-click="back-to-picker"]))
  end

  test "select-type post is ignored", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/posts/new")

    render_click(view, "select-type", %{"type" => "post"})

    assert has_element?(view, "#editor-head h1", "New recipe")
    refute has_element?(view, "#editor-head h1", "New post")
    assert has_element?(view, "#editor-publish button[type=submit]", "Post recipe")
  end

  test "back-to-picker is ignored", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/posts/new")

    html = render_click(view, "back-to-picker", %{})

    assert has_element?(view, "#editor-publish button[type=submit]", "Post recipe")
    refute html =~ "What are you sharing?"
  end

  describe "recipe editor (W250)" do
    test "editor renders and posts a recipe", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      # Every section of the Create artboard that exists today.
      assert has_element?(view, "#editor-head h1", "New recipe")
      assert has_element?(view, "#editor-photo #photo-drop-zone", "Add a photo")
      assert has_element?(view, "#editor-basics textarea[name='post[caption]']")
      assert has_element?(view, "#editor-basics input[name='post[cooking_time_minutes]']")
      assert has_element?(view, "#editor-basics input[name='post[servings]']")
      assert has_element?(view, "#editor-ingredients h2", "Ingredients")
      assert has_element?(view, "#editor-steps h2", "Steps")
      assert has_element?(view, "#editor-tools h2", "Tools")
      assert has_element?(view, "#editor-tags input[name='post[tags_input]']")
      assert has_element?(view, "#editor-preview", "Your recipe name")
      assert has_element?(view, "#editor-checklist li[data-done=false]", "A name")
      assert has_element?(view, "#editor-publish a[href='/feed']", "Cancel")

      # The ideas spec D16 leaves out are not drawn.
      refute render(view) =~ "Paste a list"
      refute render(view) =~ "Autosaved"
      refute render(view) =~ "Save draft"
      refute render(view) =~ "Add a timer"

      # Wiring: the add-row buttons still drive the existing events.
      view |> element("#editor-ingredients button", "Add ingredient") |> render_click()
      assert has_element?(view, "input[name='post[ingredients][1][name]']")
      view |> element("#editor-steps button", "Add step") |> render_click()
      assert has_element?(view, "textarea[name='post[cooking_steps][1][description]']")
      view |> element("#editor-tools button", "Add tool") |> render_click()
      assert has_element?(view, "input[name='post[tools][0][name]']")
      view |> element("button[aria-label='Remove step 2']") |> render_click()
      refute has_element?(view, "textarea[name='post[cooking_steps][1][description]']")

      photo =
        file_input(view, "#post-form", :photos, [
          %{name: "short_ribs.jpg", content: @tiny_jpeg, type: "image/jpeg"}
        ])

      render_upload(photo, "short_ribs.jpg")
      assert has_element?(view, "#editor-photo button[phx-click='cancel-upload']")

      params = %{
        caption: "Sunday short ribs\nBraise them low and slow.",
        cooking_time_minutes: "180",
        servings: "4",
        tags_input: "beef, braise",
        ingredients: %{
          "0" => %{quantity: "2", name: "short ribs", unit: "lb"},
          "1" => %{quantity: "1", name: "red wine", unit: "cup"}
        },
        cooking_steps: %{"0" => %{description: "Brown the ribs, then braise for three hours."}},
        tools: %{"0" => %{name: "Dutch oven"}}
      }

      view |> form("#post-form", post: params) |> render_change()

      # The preview and checklist follow what was typed.
      assert has_element?(view, "#editor-preview", "Sunday short ribs")
      assert has_element?(view, "#editor-preview", "180 min")
      assert has_element?(view, "#editor-checklist li[data-done=true]", "A photo")
      assert has_element?(view, "#editor-checklist li[data-done=true]", "At least one step")
      refute has_element?(view, "#editor-checklist li[data-done=false]")

      view |> form("#post-form", post: params) |> render_submit()

      post =
        Post
        |> Repo.get_by!(user_id: user.id)
        |> Repo.preload([:ingredients, :cooking_steps, :tools, :post_tags])

      stored = Path.join(Photo.upload_dir(), Path.basename(post.photo_url))
      on_exit(fn -> File.rm(stored) end)

      assert_redirect(view, ~p"/posts/#{post.id}")
      assert post.type == "recipe"
      assert post.caption == "Sunday short ribs\nBraise them low and slow."
      assert post.cooking_time_minutes == 180
      assert post.servings == 4
      assert Enum.map(post.ingredients, & &1.name) |> Enum.sort() == ["red wine", "short ribs"]
      assert [%{description: "Brown the ribs, then braise for three hours."}] = post.cooking_steps
      assert [%{name: "Dutch oven"}] = post.tools
      assert post.post_tags |> Enum.map(& &1.tag) |> Enum.sort() == ["beef", "braise"]
    end

    test "empty submit shows field errors", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      # Before anything is touched there are no notes.
      refute has_element?(view, "[data-role=field-note]")

      html =
        view
        |> form("#post-form", post: %{caption: "", cooking_time_minutes: ""})
        |> render_submit()

      # No photo: the form stays put with the existing flash, and the
      # recipe-only rule (total time required) shows as an amber note.
      refute html =~ "Post created"
      assert has_element?(view, "#editor-form-note", "Please upload at least one photo")
      assert has_element?(view, "#editor-head h1", "New recipe")

      assert has_element?(
               view,
               "#post-form_cooking_time_minutes-note p[class*='bg-accent/25']",
               "be blank"
             )

      # Amber, never red.
      refute has_element?(view, "#post-form .text-error")
      refute has_element?(view, "#post-form .input-error")
      assert has_element?(view, "#editor-checklist li[data-done=false]", "A photo")
      assert has_element?(view, "#editor-checklist li[data-done=false]", "Total time")

      # The next edit clears the save message, so it never outlives the fix.
      view |> form("#post-form", post: %{caption: "Toast"}) |> render_change()
      refute has_element?(view, "#editor-form-note")
    end

    test "invalid numbers show amber notes on their own tiles", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      view
      |> form("#post-form", post: %{caption: "Toast", cooking_time_minutes: "-5", servings: "0"})
      |> render_change()

      assert has_element?(view, "#post-form_cooking_time_minutes-note", "must be greater than 0")
      assert has_element?(view, "#post-form_servings-note", "must be greater than 0")
      refute has_element?(view, "#editor-caption-note")
    end

    test "layout collapses to one column and keeps text inside its cards", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      # One column below lg, editor | aside from lg (D116: no horizontal
      # scroll at 390 px). Every grid and flex child can shrink.
      assert has_element?(view, "form#post-form.grid.grid-cols-1")
      refute has_element?(view, "#post-form > :not(.min-w-0)")
      refute has_element?(view, "#editor-fields > :not(.min-w-0)")
      assert has_element?(view, "#editor-head h1.break-words")
      assert has_element?(view, "#editor-preview span.line-clamp-2.break-words")
    end
  end
end
