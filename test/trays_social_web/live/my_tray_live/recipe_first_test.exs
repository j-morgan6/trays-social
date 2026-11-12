defmodule TraysSocialWeb.MyTrayLive.RecipeFirstTest do
  # async: false: toggles the global :features config.
  use TraysSocialWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Posts

  # The flag is switched on per test, after fixtures are built:
  # Posts.create_post/2 rejects non-recipe posts while recipe_first is on,
  # so legacy photo-post fixtures must exist before the flip.
  setup %{conn: conn} do
    original = Application.get_env(:trays_social, :features, [])
    on_exit(fn -> Application.put_env(:trays_social, :features, original) end)
    viewer = user_fixture()
    %{conn: log_in_user(conn, viewer), viewer: viewer, original: original}
  end

  defp flag_on(original),
    do: Application.put_env(:trays_social, :features, Keyword.put(original, :recipe_first, true))

  describe "/my-tray with recipe_first on" do
    test "shows My recipes by default and Saved behind the switch", %{
      conn: conn,
      viewer: viewer,
      original: original
    } do
      post_fixture(%{user_id: viewer.id, caption: "My lasagna"})
      other = post_fixture(%{user_id: user_fixture().id, caption: "Their curry"})
      {:ok, _} = Posts.create_bookmark(viewer.id, other.id)
      flag_on(original)

      {:ok, view, _html} = live(conn, ~p"/my-tray")

      assert has_element?(view, "#my-tray-header p", "1 recipe · 1 saved")
      assert has_element?(view, "#my-tray-switch a[aria-current='page']", "My recipes")
      assert has_element?(view, "#my-tray-switch a", "Saved")
      assert has_element?(view, "#my-tray-recipes", "My lasagna")
      refute has_element?(view, "#my-tray-recipes", "Their curry")
      refute has_element?(view, "#my-tray-saved")

      view |> element("#my-tray-switch a", "Saved") |> render_click()
      assert_patch(view, ~p"/my-tray?list=saved")

      assert has_element?(view, "#my-tray-switch a[aria-current='page']", "Saved")
      assert has_element?(view, "#my-tray-saved-heading", "Saved")
      assert has_element?(view, "#my-tray-saved", "Their curry")
      refute has_element?(view, "#my-tray-recipes")
    end

    test "an unknown list falls back to My recipes", %{
      conn: conn,
      viewer: viewer,
      original: original
    } do
      post_fixture(%{user_id: viewer.id, caption: "My lasagna"})
      flag_on(original)

      {:ok, view, _html} = live(conn, ~p"/my-tray?list=bogus")

      assert has_element?(view, "#my-tray-switch a[aria-current='page']", "My recipes")
      assert has_element?(view, "#my-tray-recipes", "My lasagna")
    end

    test "My recipes excludes legacy photo posts", %{
      conn: conn,
      viewer: viewer,
      original: original
    } do
      post_fixture(%{user_id: viewer.id, caption: "My lasagna"})
      post_fixture(%{user_id: viewer.id, type: "post", caption: "Dinner out"})
      flag_on(original)

      {:ok, view, _html} = live(conn, ~p"/my-tray")

      assert has_element?(view, "#my-tray-recipes", "My lasagna")
      refute has_element?(view, "#my-tray-recipes", "Dinner out")
    end

    test "saves but no own recipes shows the first-recipe block in My recipes", %{
      conn: conn,
      viewer: viewer,
      original: original
    } do
      other = post_fixture(%{user_id: user_fixture().id, caption: "Their curry"})
      {:ok, _} = Posts.create_bookmark(viewer.id, other.id)
      flag_on(original)

      {:ok, view, _html} = live(conn, ~p"/my-tray")

      refute has_element?(view, "#my-tray-recipes")
      assert has_element?(view, "#my-tray-recipes-empty", "Your first recipe goes here.")
      assert has_element?(view, "#my-tray-recipes-empty a[href='/posts/new']", "Post a recipe")

      {:ok, view, _html} = live(conn, ~p"/my-tray?list=saved")

      assert has_element?(view, "#my-tray-saved", "Their curry")
    end

    test "own recipes but no saves shows the Saved empty block", %{
      conn: conn,
      viewer: viewer,
      original: original
    } do
      post_fixture(%{user_id: viewer.id, caption: "My lasagna"})
      flag_on(original)

      {:ok, view, html} = live(conn, ~p"/my-tray?list=saved")

      assert has_element?(view, "#my-tray-saved-empty", "Nothing saved yet.")

      assert has_element?(
               view,
               "#my-tray-saved-empty a[href='/search']",
               "Find recipes in Search"
             )

      refute html =~ "Find recipes to save"
    end

    test "an empty tray gets the new-user line and both empty blocks", %{
      conn: conn,
      original: original
    } do
      flag_on(original)

      {:ok, view, _html} = live(conn, ~p"/my-tray")

      assert has_element?(view, "#my-tray-header p", "Recipes you post and save live here.")
      assert has_element?(view, "#my-tray-recipes-empty")

      {:ok, view, _html} = live(conn, ~p"/my-tray?list=saved")

      assert has_element?(view, "#my-tray-saved-empty", "Nothing saved yet.")
    end

    test "a saved legacy photo post is labelled and keeps the card footprint", %{
      conn: conn,
      viewer: viewer,
      original: original
    } do
      cook = user_fixture()
      photo = post_fixture(%{user_id: cook.id, type: "post", caption: "Market haul"})
      recipe = post_fixture(%{user_id: cook.id, caption: "Their curry"})
      {:ok, _} = Posts.create_bookmark(viewer.id, photo.id)
      {:ok, _} = Posts.create_bookmark(viewer.id, recipe.id)
      flag_on(original)

      {:ok, view, html} = live(conn, ~p"/my-tray?list=saved")

      assert has_element?(view, "#my-tray-saved [data-legacy-photo-label]", "Market haul")
      assert html |> String.split("data-legacy-photo-label") |> length() == 2
      # Both cards are the same component with the same 4:3 photo, and both
      # title variants reserve the same two-line height (min-h-10), so a row
      # of photo posts is as tall as a row of recipes.
      assert html |> String.split("aspect-[4/3]") |> length() == 3
      assert has_element?(view, "#my-tray-saved p.min-h-10.leading-5.line-clamp-2", "Market haul")

      assert has_element?(
               view,
               "#my-tray-saved h3.min-h-10.leading-tight.line-clamp-2",
               "Their curry"
             )
    end

    test "grids start at two columns, titles reserve two lines, no sideways scroller", %{
      conn: conn,
      viewer: viewer,
      original: original
    } do
      long_name = String.pad_trailing("traycook", 30, "x")
      cook = user_fixture(%{username: long_name})
      long_title = "Braise " <> String.duplicate("slowly with onions and stock ", 4)
      post_fixture(%{user_id: viewer.id, caption: long_title})
      other = post_fixture(%{user_id: cook.id, caption: long_title})
      {:ok, _} = Posts.create_bookmark(viewer.id, other.id)
      flag_on(original)

      {:ok, view, html} = live(conn, ~p"/my-tray")

      assert has_element?(view, "#my-tray-recipes.grid.grid-cols-2")
      assert has_element?(view, "#my-tray-recipes h3.line-clamp-2.min-h-10")
      refute html =~ "overflow-x"

      {:ok, view, html} = live(conn, ~p"/my-tray?list=saved")

      assert has_element?(view, "#my-tray-saved.grid.grid-cols-2")
      assert has_element?(view, "#my-tray-saved span.truncate", long_name)
      refute html =~ "overflow-x"
    end
  end

  describe "/my-tray with recipe_first off" do
    test "renders no recipe-first sections", %{conn: conn, viewer: viewer} do
      post_fixture(%{user_id: viewer.id, caption: "My lasagna"})

      {:ok, view, _html} = live(conn, ~p"/my-tray")

      refute has_element?(view, "#my-tray-switch")
      refute has_element?(view, "#my-tray-recipes")
      refute has_element?(view, "#my-tray-saved-heading")
      refute has_element?(view, "#my-tray-saved-empty")
    end

    test "ignores the list param and shows the Saved grid", %{conn: conn, viewer: viewer} do
      other = post_fixture(%{user_id: user_fixture().id, caption: "Their curry"})
      {:ok, _} = Posts.create_bookmark(viewer.id, other.id)

      {:ok, view, _html} = live(conn, ~p"/my-tray?list=recipes")

      assert has_element?(view, "#saved-recipes.grid.grid-cols-2", "Their curry")
      refute has_element?(view, "[data-legacy-photo-label]")
    end
  end

  describe "profile Photo label" do
    test "profile labels legacy photo posts", %{conn: conn, viewer: viewer, original: original} do
      post_fixture(%{user_id: viewer.id, type: "post", caption: "Dinner out"})
      post_fixture(%{user_id: viewer.id, caption: "My lasagna"})
      flag_on(original)

      {:ok, view, html} = live(conn, ~p"/@#{viewer.username}")

      assert has_element?(view, "[data-legacy-photo-label]", "Photo")
      assert html |> String.split("data-legacy-photo-label") |> length() == 2
    end

    test "no label with the flag off", %{conn: conn, viewer: viewer} do
      post_fixture(%{user_id: viewer.id, type: "post", caption: "Dinner out"})

      {:ok, view, _html} = live(conn, ~p"/@#{viewer.username}")

      refute has_element?(view, "[data-legacy-photo-label]")
    end
  end

  # W246: a profile is a cook's recipes. Nobody's Saved list shows on it,
  # with the flag on or off, on someone else's profile or your own.
  describe "profile never shows a Saved list" do
    setup %{viewer: viewer} do
      friend = user_fixture()
      post_fixture(%{user_id: friend.id, caption: "Friend's stew"})
      third = post_fixture(%{user_id: user_fixture().id, caption: "Their curry"})
      {:ok, _} = Posts.create_bookmark(friend.id, third.id)
      {:ok, _} = Posts.create_bookmark(viewer.id, third.id)
      %{friend: friend}
    end

    test "with the flag on", %{conn: conn, friend: friend, viewer: viewer, original: original} do
      flag_on(original)

      for user <- [friend, viewer] do
        {:ok, view, html} = live(conn, ~p"/@#{user.username}")

        refute html =~ "Their curry"
        refute has_element?(view, "main", "Saved")
        refute has_element?(view, "#my-tray-saved")
      end
    end

    test "with the flag off", %{conn: conn, friend: friend, viewer: viewer} do
      for user <- [friend, viewer] do
        {:ok, view, html} = live(conn, ~p"/@#{user.username}")

        refute html =~ "Their curry"
        refute has_element?(view, "main", "Saved")
      end

      {:ok, view, _html} = live(conn, ~p"/@#{friend.username}")
      assert has_element?(view, "#profile-posts", "Friend's stew")
    end
  end
end
