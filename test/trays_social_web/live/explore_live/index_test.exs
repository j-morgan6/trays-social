defmodule TraysSocialWeb.ExploreLive.IndexTest do
  use TraysSocialWeb.ConnCase

  import Phoenix.LiveViewTest
  import TraysSocial.PostsFixtures
  import TraysSocial.AccountsFixtures

  describe "Explore page" do
    test "renders the explore page with loading state on initial mount", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/explore")

      assert html =~ "Explore"
    end

    test "shows empty state when no posts exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/explore")

      # After connected mount, loading is false and empty state should show
      html = render(view)
      assert html =~ "Nothing to explore yet"
    end

    test "shows 'Log in to post' button for unauthenticated user in empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/explore")

      html = render(view)
      assert html =~ "Log in to post"
    end

    test "shows 'Create a post' button for authenticated user in empty state", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/explore")

      html = render(view)
      assert html =~ "Create a post"
    end

    test "displays trending posts when they exist", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      # Bump like_count directly to make the post appear in trending
      post
      |> Ecto.Changeset.change(%{like_count: 5})
      |> TraysSocial.Repo.update!()

      {:ok, view, _html} = live(conn, ~p"/explore")

      html = render(view)
      assert html =~ "Trending"
      assert html =~ user.username
    end

    test "displays recent posts", %{conn: conn} do
      user = user_fixture()
      _post = post_fixture(user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/explore")

      html = render(view)
      assert html =~ "New"
      assert html =~ user.username
    end

    test "is accessible without authentication", %{conn: conn} do
      # Explore is a public route per the router
      {:ok, _view, html} = live(conn, ~p"/explore")

      assert html =~ "Explore"
    end
  end
end
