defmodule TraysSocialWeb.PostLive.NewRecipeFirstTest do
  # async: false: toggles the global :features config.
  use TraysSocialWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures

  setup %{conn: conn} do
    original = Application.get_env(:trays_social, :features, [])
    Application.put_env(:trays_social, :features, Keyword.put(original, :recipe_first, true))
    on_exit(fn -> Application.put_env(:trays_social, :features, original) end)
    %{conn: log_in_user(conn, user_fixture())}
  end

  test "opens straight on the recipe form", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/posts/new")

    refute html =~ "What are you sharing?"
    refute html =~ "Share a post"
    assert html =~ "Publish recipe"
    refute has_element?(view, ~s([phx-click="back-to-picker"]))
  end

  test "select-type post is ignored", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/posts/new")

    html = render_click(view, "select-type", %{"type" => "post"})

    assert html =~ "Publish recipe"
    refute html =~ "Publish post"
  end

  test "back-to-picker is ignored", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/posts/new")

    html = render_click(view, "back-to-picker", %{})

    assert html =~ "Publish recipe"
    refute html =~ "What are you sharing?"
  end
end
