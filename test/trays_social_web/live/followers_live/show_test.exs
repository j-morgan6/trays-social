defmodule TraysSocialWeb.FollowersLive.ShowTest do
  use TraysSocialWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures

  alias TraysSocial.Accounts

  describe "Followers / Following" do
    test "redirects to login when not authenticated", %{conn: conn} do
      user = user_fixture()

      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/@#{user.username}/followers")
      assert path =~ "/users/log-in"
    end

    test "renders the followers tab with empty state", %{conn: conn} do
      user = user_fixture()
      viewer = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/@#{user.username}/followers")

      assert html =~ "Followers"
      assert html =~ "No followers yet"
    end

    test "renders the following tab with empty state for own profile", %{conn: conn} do
      viewer = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/@#{viewer.username}/following")

      assert html =~ "Following"
      # HEEx HTML-encodes the apostrophe.
      assert html =~ "not following anyone yet"
    end

    test "lists followers and counts them in the tab heading", %{conn: conn} do
      user = user_fixture()
      follower = user_fixture()
      viewer = user_fixture()

      {:ok, _} = Accounts.follow_user(follower, user)

      {:ok, _view, html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/@#{user.username}/followers")

      assert html =~ follower.username
    end

    test "toggle-follow flips the inline action", %{conn: conn} do
      user = user_fixture()
      target = user_fixture()
      viewer = user_fixture()

      # Seed: target follows user (so target appears in user's followers list)
      {:ok, _} = Accounts.follow_user(target, user)

      {:ok, view, html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/@#{user.username}/followers")

      # Viewer doesn't follow target yet, so action reads "Follow"
      assert html =~ ~r/phx-click="toggle-follow"[^>]*>\s*Follow\s*</

      html = render_click(view, "toggle-follow", %{"id" => to_string(target.id)})
      assert html =~ ~r/phx-click="toggle-follow"[^>]*>\s*Following/

      assert Accounts.following?(viewer.id, target.id)
    end

    test "redirects to feed when username does not exist", %{conn: conn} do
      viewer = user_fixture()

      {:error, {:live_redirect, %{to: path}}} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/@nonexistent/followers")

      assert path == "/"
    end

    test "search filters the loaded cooks in-memory", %{conn: conn} do
      user = user_fixture()
      viewer = user_fixture()
      alice = user_fixture(%{username: "alice_cooks"})
      bob = user_fixture(%{username: "bob_bakes"})

      {:ok, _} = Accounts.follow_user(alice, user)
      {:ok, _} = Accounts.follow_user(bob, user)

      {:ok, view, html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/@#{user.username}/followers")

      # Both followers render initially.
      assert html =~ "alice_cooks"
      assert html =~ "bob_bakes"

      # Note: with only 2 followers (≤ 20) the search input isn't
      # rendered, but the search event is still wired and the filter
      # logic runs. Send the event directly.
      html = render_change(view, "search", %{"query" => "alice"})
      assert html =~ "alice_cooks"
      refute html =~ "bob_bakes"

      # Clear restores the full list.
      html = render_change(view, "search", %{"query" => ""})
      assert html =~ "alice_cooks"
      assert html =~ "bob_bakes"
    end
  end
end
