defmodule TraysSocialWeb.HomeLive.IndexTest do
  # async: false: toggles the global :features config.
  use TraysSocialWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Accounts

  setup %{conn: conn} do
    original = Application.get_env(:trays_social, :features, [])
    on_exit(fn -> Application.put_env(:trays_social, :features, original) end)
    viewer = user_fixture()
    %{conn: log_in_user(conn, viewer), viewer: viewer, original: original}
  end

  defp flag_on(original),
    do: Application.put_env(:trays_social, :features, Keyword.put(original, :recipe_first, true))

  defp count(html, fragment), do: length(String.split(html, fragment)) - 1

  describe "/home" do
    test "new user sees the welcome block", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/home")

      assert html =~ "Welcome to Trays"
      assert has_element?(view, "#home-welcome a", "Post your first recipe")
      refute has_element?(view, "#home-friends")
      refute has_element?(view, "#home-new")
    end

    test "renders tray, friends, and the finite row", %{conn: conn, viewer: viewer} do
      friend = user_fixture()
      {:ok, _} = Accounts.follow_user(viewer, friend)
      post_fixture(%{user_id: viewer.id, caption: "My chili"})
      post_fixture(%{user_id: friend.id, caption: "Friend focaccia"})

      {:ok, view, _html} = live(conn, ~p"/home")

      refute has_element?(view, "#home-welcome")
      assert has_element?(view, "#home-jump-back-in", "Jump back in")
      assert has_element?(view, "#home-jump-back-in", "My chili")
      assert has_element?(view, "#home-friends", "Friends' trays")
      assert has_element?(view, "#home-friends", friend.username)
      assert has_element?(view, "#home-new", "New from people you follow")
      assert has_element?(view, "#home-new", "Friend focaccia")
      assert has_element?(view, "#home-caught-up", "You're caught up")
    end

    test "guests are sent to log in" do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(build_conn(), ~p"/home")
    end
  end

  describe "redirects" do
    test "flag on: /feed redirects to /home", %{conn: conn, original: original} do
      flag_on(original)
      assert {:error, {:live_redirect, %{to: "/home"}}} = live(conn, ~p"/feed")
    end

    test "flag on: an unfinished cook still sees /welcome first", %{original: original} do
      flag_on(original)
      conn = log_in_user(build_conn(), unfinished_user_fixture())
      assert {:error, {:live_redirect, %{to: "/welcome"}}} = live(conn, ~p"/feed")
    end

    test "flag off: /feed still renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/feed")

      assert html =~ ~s(href="/feed")
      refute html =~ ~s(href="/home")
    end

    test "flag on: / sends logged-in users to /home", %{conn: conn, original: original} do
      flag_on(original)
      assert redirected_to(get(conn, ~p"/")) == "/home"
    end

    test "flag off: / sends logged-in users to /feed", %{conn: conn} do
      assert redirected_to(get(conn, ~p"/")) == "/feed"
    end

    test "flag on: sign-in lands on /home", %{viewer: viewer, original: original} do
      flag_on(original)
      viewer = set_password(viewer)

      conn =
        post(build_conn(), ~p"/users/log-in", %{
          "user" => %{"email" => viewer.email, "password" => valid_user_password()}
        })

      assert redirected_to(conn) == "/home"
    end

    test "flag on: signed-in visitors to guest pages go to /home", %{
      conn: conn,
      original: original
    } do
      flag_on(original)
      assert redirected_to(get(conn, ~p"/users/register")) == "/home"
    end
  end

  describe "nav" do
    test "flag on: nav shows Home and Search", %{conn: conn, original: original} do
      flag_on(original)
      html = conn |> get(~p"/home") |> html_response(200)

      # Desktop and mobile each link Home, Search and My Tray; the header
      # search pill is a third /search link.
      assert count(html, ~s(href="/home")) == 2
      assert count(html, ~s(href="/search")) == 3
      assert count(html, ~s(href="/my-tray")) == 2
      assert html =~ "<span>Home</span>"
      assert html =~ "<span>Search</span>"
      assert html =~ "<span>My Tray</span>"
      refute html =~ ~s(href="/feed")
      refute html =~ ~s(href="/explore")
      refute html =~ "<span>Feed</span>"
      refute html =~ "<span>Profile</span>"
    end

    test "flag off: nav keeps Feed, Find and Explore", %{conn: conn} do
      html = conn |> get(~p"/home") |> html_response(200)

      assert count(html, ~s(href="/feed")) == 2
      assert count(html, ~s(href="/explore")) == 3
      assert count(html, ~s(href="/my-tray")) == 1
      assert html =~ "<span>Feed</span>"
      assert html =~ "<span>Profile</span>"
      assert html =~ ~s(<span class="hero-user w-6 h-6"></span>)
      refute html =~ ~s(href="/home")
      refute html =~ ~s(href="/search")
    end

    test "flag on: guest nav is unchanged", %{original: original} do
      flag_on(original)
      html = build_conn() |> get(~p"/users/log-in") |> html_response(200)

      assert html =~ ~s(href="/feed")
      assert html =~ ~s(href="/explore")
      refute html =~ ~s(href="/home")
      refute html =~ ~s(href="/search")
    end
  end
end
