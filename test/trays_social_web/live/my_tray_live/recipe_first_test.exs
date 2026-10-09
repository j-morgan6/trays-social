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
    test "shows My recipes and Saved", %{conn: conn, viewer: viewer, original: original} do
      post_fixture(%{user_id: viewer.id, caption: "My lasagna"})
      other = post_fixture(%{user_id: user_fixture().id, caption: "Their curry"})
      {:ok, _} = Posts.create_bookmark(viewer.id, other.id)
      flag_on(original)

      {:ok, view, html} = live(conn, ~p"/my-tray")

      assert has_element?(view, "#my-tray-recipes h2", "My recipes")
      assert has_element?(view, "#my-tray-recipes", "My lasagna")
      refute has_element?(view, "#my-tray-recipes", "Their curry")
      assert has_element?(view, "#my-tray-saved-heading", "Saved")
      assert html =~ "Their curry"
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

    test "saves but no own recipes hides My recipes", %{
      conn: conn,
      viewer: viewer,
      original: original
    } do
      other = post_fixture(%{user_id: user_fixture().id, caption: "Their curry"})
      {:ok, _} = Posts.create_bookmark(viewer.id, other.id)
      flag_on(original)

      {:ok, view, html} = live(conn, ~p"/my-tray")

      refute has_element?(view, "#my-tray-recipes")
      assert has_element?(view, "#my-tray-saved-heading", "Saved")
      assert html =~ "Their curry"
    end

    test "own recipes but no saves shows a short note, not the big empty state", %{
      conn: conn,
      viewer: viewer,
      original: original
    } do
      post_fixture(%{user_id: viewer.id, caption: "My lasagna"})
      flag_on(original)

      {:ok, view, html} = live(conn, ~p"/my-tray")

      assert has_element?(view, "#my-tray-recipes", "My lasagna")
      assert has_element?(view, "#my-tray-saved-empty", "Nothing saved yet.")
      refute html =~ "Find recipes to save"
    end

    test "both lists empty keeps the empty state", %{conn: conn, original: original} do
      flag_on(original)

      {:ok, view, html} = live(conn, ~p"/my-tray")

      refute has_element?(view, "#my-tray-recipes")
      assert html =~ "Nothing saved yet."
      assert html =~ "Find recipes to save"
    end
  end

  describe "/my-tray with recipe_first off" do
    test "renders no recipe-first sections", %{conn: conn, viewer: viewer} do
      post_fixture(%{user_id: viewer.id, caption: "My lasagna"})

      {:ok, view, _html} = live(conn, ~p"/my-tray")

      refute has_element?(view, "#my-tray-recipes")
      refute has_element?(view, "#my-tray-saved-heading")
      refute has_element?(view, "#my-tray-saved-empty")
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
end
