defmodule TraysSocialWeb.ProfileLive.ShowTest do
  use TraysSocialWeb.ConnCase

  import Phoenix.LiveViewTest
  import TraysSocial.PostsFixtures
  import TraysSocial.AccountsFixtures

  describe "Profile page" do
    test "displays user profile information", %{conn: conn} do
      user = user_fixture()
      # Update user with bio
      {:ok, user} =
        user
        |> Ecto.Changeset.change(%{bio: "Love cooking!"})
        |> TraysSocial.Repo.update()

      {:ok, _view, html} = live(conn, ~p"/@#{user.username}")

      assert html =~ user.username
      assert html =~ "Love cooking!"
      assert html =~ "0"
      assert html =~ "posts"
    end

    test "displays user profile with posts", %{conn: conn} do
      user = user_fixture()
      post1 = post_fixture(user_id: user.id)
      post2 = post_fixture(user_id: user.id)

      {:ok, _view, html} = live(conn, ~p"/@#{user.username}")

      assert html =~ user.username
      assert html =~ "2"
      assert html =~ "posts"
      # Posts should be displayed in grid using thumb variants
      assert html =~ TraysSocial.Uploads.ImageProcessor.thumb_url(post1.photo_url)
      assert html =~ TraysSocial.Uploads.ImageProcessor.thumb_url(post2.photo_url)
    end

    test "shows edit profile button for own profile", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/@#{user.username}")

      assert html =~ "Edit Profile"
    end

    test "does not show edit profile button for other users", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(other_user)
        |> live(~p"/@#{user.username}")

      refute html =~ "Edit Profile"
    end

    test "displays placeholder avatar when no profile photo", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} = live(conn, ~p"/@#{user.username}")

      # Should show first letter of username in placeholder
      first_letter = String.first(user.username) |> String.upcase()
      assert html =~ first_letter
    end

    test "shows profile photo when set", %{conn: conn} do
      user = user_fixture()
      # Update user with profile photo
      {:ok, user} =
        user
        |> Ecto.Changeset.change(%{profile_photo_url: "https://example.com/photo.jpg"})
        |> TraysSocial.Repo.update()

      {:ok, _view, html} = live(conn, ~p"/@#{user.username}")

      assert html =~ "https://example.com/photo.jpg"
    end

    test "redirects to feed when user not found", %{conn: conn} do
      {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/@nonexistentuser")

      assert path == "/"
    end

    test "clicking on post navigates to post detail", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/@#{user.username}")

      assert view
             |> element("a[href='/posts/#{post.id}']")
             |> render_click()

      assert_redirect(view, ~p"/posts/#{post.id}")
    end

    test "shows follow button for authenticated user viewing another profile", %{conn: conn} do
      user = user_fixture()
      viewer = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/@#{user.username}")

      assert html =~ "Follow"
    end

    test "toggle-follow redirects unauthenticated user to login", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = live(conn, ~p"/@#{user.username}")

      render_click(view, "toggle-follow")
      assert_redirect(view, ~p"/users/log-in")
    end

    test "authenticated user can follow and unfollow another user", %{conn: conn} do
      user = user_fixture()
      viewer = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/@#{user.username}")

      # Follow the user
      html = render_click(view, "toggle-follow")
      assert html =~ "Following"

      # Unfollow the user
      html = render_click(view, "toggle-follow")
      assert html =~ "Follow"
      refute html =~ "Following"
    end

    test "displays follower and following counts", %{conn: conn} do
      user = user_fixture()
      follower = user_fixture()

      # Create a follow relationship
      TraysSocial.Accounts.follow_user(follower, user)

      {:ok, _view, html} =
        conn
        |> log_in_user(follower)
        |> live(~p"/@#{user.username}")

      # Should show 1 follower
      assert html =~ "1"
      assert html =~ "follower"
    end

    test "displays following count for own profile", %{conn: conn} do
      user = user_fixture()
      other = user_fixture()

      TraysSocial.Accounts.follow_user(user, other)

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/@#{user.username}")

      assert html =~ "following"
    end

    test "shows empty posts state for own profile with no posts", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/@#{user.username}")

      assert html =~ "No posts yet"
      assert html =~ "Share your first post"
    end

    test "shows empty posts state for other user with no posts", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} = live(conn, ~p"/@#{user.username}")

      assert html =~ "No posts yet"
    end
  end
end
