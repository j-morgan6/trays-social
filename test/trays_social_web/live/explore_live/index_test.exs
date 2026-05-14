defmodule TraysSocialWeb.ExploreLive.IndexTest do
  use TraysSocialWeb.ConnCase

  import Phoenix.LiveViewTest
  import TraysSocial.PostsFixtures
  import TraysSocial.AccountsFixtures

  describe "Explore page" do
    # /explore requires authentication (D60). Setup logs in a viewer so
    # rendering tests below continue to exercise the page.
    setup %{conn: conn} do
      viewer = user_fixture()
      %{conn: log_in_user(conn, viewer), viewer: viewer}
    end

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

    test "shows 'Create a post' button in empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/explore")

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
  end

  describe "Authentication (D60)" do
    test "anonymous visitors are redirected to login", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/explore")
      assert path =~ "/users/log-in"
    end
  end
end
