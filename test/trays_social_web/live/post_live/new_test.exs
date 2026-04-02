defmodule TraysSocialWeb.PostLive.NewTest do
  use TraysSocialWeb.ConnCase

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures

  # Minimal valid JPEG binary (a tiny 1x1 pixel JPEG)
  @tiny_jpeg <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00,
               0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43, 0x00, 0x08, 0x06, 0x06,
               0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09, 0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D,
               0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12, 0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D,
               0x1A, 0x1C, 0x1C, 0x20, 0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28,
               0x37, 0x29, 0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
               0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, 0x00, 0x01,
               0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00, 0x01, 0x05, 0x01, 0x01,
               0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02,
               0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0xFF, 0xC4, 0x00, 0xB5, 0x10,
               0x00, 0x02, 0x01, 0x03, 0x03, 0x02, 0x04, 0x03, 0x05, 0x05, 0x04, 0x04, 0x00, 0x00,
               0x01, 0x7D, 0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06,
               0x13, 0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08, 0x23, 0x42,
               0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0, 0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0A, 0x16,
               0x17, 0x18, 0x19, 0x1A, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x34, 0x35, 0x36, 0x37,
               0x38, 0x39, 0x3A, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x53, 0x54, 0x55,
               0x56, 0x57, 0x58, 0x59, 0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x73,
               0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
               0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3, 0xA4, 0xA5,
               0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA,
               0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6,
               0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA,
               0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFF, 0xDA, 0x00, 0x08,
               0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, 0x7B, 0x94, 0x11, 0x00, 0x00, 0x00, 0x00, 0x00,
               0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xD9>>

  defp authenticated_live(conn, path) do
    user = user_fixture()

    {:ok, view, html} =
      conn
      |> log_in_user(user)
      |> live(path)

    {user, view, html}
  end

  defp authenticated_live_with_type(conn, path, type) do
    {user, view, _html} = authenticated_live(conn, path)
    html = render_click(view, "select-type", %{"type" => type})
    {user, view, html}
  end

  defp select_type(view, type) do
    html = render_click(view, "select-type", %{"type" => type})
    {view, html}
  end

  describe "Type picker" do
    test "redirects unauthenticated user to login", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/posts/new")
      assert {:redirect, %{to: to}} = redirect
      assert to =~ "/users/log-in"
    end

    test "shows type picker on initial load", %{conn: conn} do
      {_user, _view, html} = authenticated_live(conn, ~p"/posts/new")

      assert html =~ "What are you sharing?"
      assert html =~ "Recipe"
      assert html =~ "Share how you made it"
      assert html =~ "Post"
      assert html =~ "Share what you&#39;re eating"
    end

    test "page title is set to Create Post", %{conn: conn} do
      {_user, _view, html} = authenticated_live(conn, ~p"/posts/new")
      assert html =~ "Create Post"
    end

    test "selecting Recipe shows recipe form", %{conn: conn} do
      {_user, view, _html} = authenticated_live(conn, ~p"/posts/new")
      {_view, html} = select_type(view, "recipe")

      assert html =~ "Create Recipe"
      assert html =~ "Caption"
      assert html =~ "Ingredients"
      assert html =~ "Cooking Steps"
      assert html =~ "Publish"
    end

    test "selecting Post shows minimal post form", %{conn: conn} do
      {_user, view, _html} = authenticated_live(conn, ~p"/posts/new")
      {_view, html} = select_type(view, "post")

      assert html =~ "Create Post"
      assert html =~ "Caption"
      assert html =~ "Tags"
      refute html =~ "Ingredients"
      refute html =~ "Cooking Steps"
      refute html =~ "Cooking Time"
    end

    test "back button returns to type picker", %{conn: conn} do
      {_user, view, _html} = authenticated_live(conn, ~p"/posts/new")
      select_type(view, "recipe")

      html = render_click(view, "back-to-picker")

      assert html =~ "What are you sharing?"
      refute html =~ "Ingredients"
    end
  end

  describe "Recipe form" do
    test "shows photo upload area", %{conn: conn} do
      {_user, view, _html} = authenticated_live(conn, ~p"/posts/new")
      {_view, html} = select_type(view, "recipe")

      assert html =~ "Photos"
      assert html =~ "Drop photos here"
      assert html =~ "up to 5 photos"
    end

    test "shows tags input field", %{conn: conn} do
      {_user, view, _html} = authenticated_live(conn, ~p"/posts/new")
      {_view, html} = select_type(view, "recipe")

      assert html =~ "Tags"
      assert html =~ "post[tags_input]"
      assert html =~ "Separate multiple tags with commas"
    end

    test "initial state has one ingredient row, one step row, no tool rows", %{conn: conn} do
      {_user, view, _html} = authenticated_live(conn, ~p"/posts/new")
      {_view, html} = select_type(view, "recipe")

      assert html =~ "post[ingredients][0][name]"
      assert html =~ "post[cooking_steps][0][description]"
      assert html =~ "No tools added"
      assert html =~ "Drop photos here"
    end

    test "does not show difficulty select", %{conn: conn} do
      {_user, view, _html} = authenticated_live(conn, ~p"/posts/new")
      {_view, html} = select_type(view, "recipe")

      refute html =~ "Select difficulty"
    end
  end

  describe "validate event" do
    test "form validates on change with empty fields", %{conn: conn} do
      {_user, view, _html} = authenticated_live(conn, ~p"/posts/new")
      select_type(view, "recipe")

      html =
        view
        |> form("#post-form", post: %{caption: "", cooking_time_minutes: ""})
        |> render_change()

      assert html =~ "Create Recipe"
    end

    test "validates with valid caption and cooking time", %{conn: conn} do
      {_user, view, _html} = authenticated_live(conn, ~p"/posts/new")
      select_type(view, "recipe")

      html =
        view
        |> form("#post-form",
          post: %{caption: "Delicious pasta", cooking_time_minutes: 30}
        )
        |> render_change()

      assert html =~ "Create Recipe"
      refute html =~ "can&#39;t be blank"
    end

    test "shows validation error for caption exceeding max length", %{conn: conn} do
      {_user, view, _html} = authenticated_live(conn, ~p"/posts/new")
      select_type(view, "recipe")

      long_caption = String.duplicate("a", 501)

      html =
        view
        |> form("#post-form", post: %{caption: long_caption, cooking_time_minutes: 30})
        |> render_change()

      assert html =~ "should be at most 500 character"
    end

    test "shows validation error for negative cooking time", %{conn: conn} do
      {_user, view, _html} = authenticated_live(conn, ~p"/posts/new")
      select_type(view, "recipe")

      html =
        view
        |> form("#post-form", post: %{caption: "Test", cooking_time_minutes: -5})
        |> render_change()

      assert html =~ "must be greater than 0"
    end

    test "validates with negative servings", %{conn: conn} do
      {_user, view, _html} = authenticated_live(conn, ~p"/posts/new")
      select_type(view, "recipe")

      html =
        view
        |> form("#post-form",
          post: %{caption: "Test", cooking_time_minutes: 10, servings: -1}
        )
        |> render_change()

      assert html =~ "must be greater than 0"
    end
  end

  describe "ingredient management" do
    test "add and remove ingredient rows", %{conn: conn} do
      {_user, view, _html} = authenticated_live(conn, ~p"/posts/new")
      {_view, html} = select_type(view, "recipe")

      assert html =~ "post[ingredients][0][name]"

      html = render_click(view, "add-ingredient")
      assert html =~ "post[ingredients][0][name]"
      assert html =~ "post[ingredients][1][name]"

      html = render_click(view, "remove-ingredient", %{"id" => "0"})
      refute html =~ "post[ingredients][0][name]"
      assert html =~ "post[ingredients][1][name]"
    end

    test "adding multiple ingredients increments IDs correctly", %{conn: conn} do
      {_user, view, _html} = authenticated_live_with_type(conn, ~p"/posts/new", "recipe")

      render_click(view, "add-ingredient")
      render_click(view, "add-ingredient")
      html = render_click(view, "add-ingredient")

      assert html =~ "post[ingredients][0][name]"
      assert html =~ "post[ingredients][1][name]"
      assert html =~ "post[ingredients][2][name]"
      assert html =~ "post[ingredients][3][name]"
    end

    test "removing middle ingredient preserves others", %{conn: conn} do
      {_user, view, _html} = authenticated_live_with_type(conn, ~p"/posts/new", "recipe")

      render_click(view, "add-ingredient")
      render_click(view, "add-ingredient")

      html = render_click(view, "remove-ingredient", %{"id" => "1"})

      assert html =~ "post[ingredients][0][name]"
      refute html =~ "post[ingredients][1][name]"
      assert html =~ "post[ingredients][2][name]"
    end
  end

  describe "step management" do
    test "add and remove step rows", %{conn: conn} do
      {_user, view, _html} = authenticated_live_with_type(conn, ~p"/posts/new", "recipe")

      html = render_click(view, "add-step")
      assert html =~ "post[cooking_steps][0][description]"
      assert html =~ "post[cooking_steps][1][description]"

      html = render_click(view, "remove-step", %{"id" => "0"})
      refute html =~ "post[cooking_steps][0][description]"
      assert html =~ "post[cooking_steps][1][description]"
    end

    test "adding multiple steps increments IDs correctly", %{conn: conn} do
      {_user, view, _html} = authenticated_live_with_type(conn, ~p"/posts/new", "recipe")

      render_click(view, "add-step")
      html = render_click(view, "add-step")

      assert html =~ "post[cooking_steps][0][description]"
      assert html =~ "post[cooking_steps][1][description]"
      assert html =~ "post[cooking_steps][2][description]"
    end

    test "removing middle step preserves others", %{conn: conn} do
      {_user, view, _html} = authenticated_live_with_type(conn, ~p"/posts/new", "recipe")

      render_click(view, "add-step")
      render_click(view, "add-step")

      html = render_click(view, "remove-step", %{"id" => "1"})

      assert html =~ "post[cooking_steps][0][description]"
      refute html =~ "post[cooking_steps][1][description]"
      assert html =~ "post[cooking_steps][2][description]"
    end
  end

  describe "tool management" do
    test "add and remove tool rows", %{conn: conn} do
      {_user, view, html} = authenticated_live_with_type(conn, ~p"/posts/new", "recipe")

      assert html =~ "No tools added"

      html = render_click(view, "add-tool")
      refute html =~ "No tools added"
      assert html =~ "post[tools][0][name]"

      html = render_click(view, "add-tool")
      assert html =~ "post[tools][0][name]"
      assert html =~ "post[tools][1][name]"

      html = render_click(view, "remove-tool", %{"id" => "0"})
      refute html =~ "post[tools][0][name]"
      assert html =~ "post[tools][1][name]"
    end

    test "adding multiple tools increments IDs correctly", %{conn: conn} do
      {_user, view, _html} = authenticated_live_with_type(conn, ~p"/posts/new", "recipe")

      render_click(view, "add-tool")
      render_click(view, "add-tool")
      html = render_click(view, "add-tool")

      assert html =~ "post[tools][0][name]"
      assert html =~ "post[tools][1][name]"
      assert html =~ "post[tools][2][name]"
    end

    test "removing all tools shows empty state", %{conn: conn} do
      {_user, view, _html} = authenticated_live_with_type(conn, ~p"/posts/new", "recipe")

      render_click(view, "add-tool")
      html = render_click(view, "remove-tool", %{"id" => "0"})

      assert html =~ "No tools added"
    end
  end

  describe "save event without photos" do
    test "save without photos keeps user on form", %{conn: conn} do
      {_user, view, _html} = authenticated_live_with_type(conn, ~p"/posts/new", "recipe")

      view
      |> form("#post-form", post: %{caption: "Test caption", cooking_time_minutes: 30})
      |> render_submit()

      html = render(view)
      assert html =~ "Create Recipe"
      assert html =~ "Publish"
    end

    test "save without photos triggers the no-photo error path", %{conn: conn} do
      {_user, view, _html} = authenticated_live_with_type(conn, ~p"/posts/new", "recipe")

      # Submit with valid form data but no photos
      # This exercises the empty entries path in handle_event("save")
      view
      |> form("#post-form", post: %{caption: "Test", cooking_time_minutes: 30})
      |> render_submit()

      # User should stay on the form (not redirected)
      html = render(view)
      assert html =~ "Create Recipe"
    end
  end

  describe "file upload" do
    test "can upload a photo and see cancel button", %{conn: conn} do
      {_user, view, _html} = authenticated_live_with_type(conn, ~p"/posts/new", "recipe")

      photo =
        file_input(view, "#post-form", :photos, [
          %{
            name: "test_photo.jpg",
            content: @tiny_jpeg,
            type: "image/jpeg"
          }
        ])

      assert render_upload(photo, "test_photo.jpg") =~ "cancel-upload"
    end

    test "upload with multiple photos shows all previews", %{conn: conn} do
      {_user, view, _html} = authenticated_live_with_type(conn, ~p"/posts/new", "recipe")

      photos =
        file_input(view, "#post-form", :photos, [
          %{name: "photo1.jpg", content: @tiny_jpeg, type: "image/jpeg"},
          %{name: "photo2.jpg", content: @tiny_jpeg, type: "image/jpeg"}
        ])

      render_upload(photos, "photo1.jpg")
      html = render_upload(photos, "photo2.jpg")

      assert html =~ "Add more"
    end
  end

  describe "upload error display" do
    test "too many files triggers error in rendered output", %{conn: conn} do
      {_user, view, _html} = authenticated_live_with_type(conn, ~p"/posts/new", "recipe")

      photo =
        file_input(view, "#post-form", :photos, [
          %{name: "p1.jpg", content: @tiny_jpeg, type: "image/jpeg"},
          %{name: "p2.jpg", content: @tiny_jpeg, type: "image/jpeg"},
          %{name: "p3.jpg", content: @tiny_jpeg, type: "image/jpeg"},
          %{name: "p4.jpg", content: @tiny_jpeg, type: "image/jpeg"},
          %{name: "p5.jpg", content: @tiny_jpeg, type: "image/jpeg"},
          %{name: "p6.jpg", content: @tiny_jpeg, type: "image/jpeg"}
        ])

      assert {:error, [[_ref, :too_many_files]]} = preflight_upload(photo)

      html = render(view)
      assert html =~ "Too many files selected"
    end

    test "non-accepted file type triggers error in rendered output", %{conn: conn} do
      {_user, view, _html} = authenticated_live_with_type(conn, ~p"/posts/new", "recipe")

      photo =
        file_input(view, "#post-form", :photos, [
          %{name: "document.pdf", content: "not a real photo", type: "application/pdf"}
        ])

      assert {:error, [[_ref, :not_accepted]]} = preflight_upload(photo)

      html = render(view)
      assert html =~ "File type not accepted"
    end
  end
end
