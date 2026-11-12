defmodule TraysSocialWeb.ProfileLive.ShowTest do
  use TraysSocialWeb.ConnCase

  import Phoenix.LiveViewTest
  import TraysSocial.PostsFixtures
  import TraysSocial.AccountsFixtures

  describe "Profile page" do
    # /@:username requires authentication (D60). Setup logs in a viewer so the
    # rendering tests below continue to exercise the profile UI. Tests that
    # need a specific logged-in user (own profile, follow flow) call
    # log_in_user explicitly to override.
    setup %{conn: conn} do
      viewer = user_fixture()
      %{conn: log_in_user(conn, viewer), viewer: viewer}
    end

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
      # W246: posts sit in a uniform two-column grid of recipe cards, which
      # show the medium variant.
      assert html =~ TraysSocial.Uploads.ImageProcessor.medium_url(post1.photo_url)
      assert html =~ TraysSocial.Uploads.ImageProcessor.medium_url(post2.photo_url)
    end

    test "renders the header card, the Recipes heading and an equal-size grid", %{conn: conn} do
      user = user_fixture(%{username: String.pad_trailing("longprofile", 30, "x")})
      post_fixture(user_id: user.id)
      post_fixture(user_id: user.id)

      {:ok, view, html} = live(conn, ~p"/@#{user.username}")

      assert has_element?(view, "#profile-header.bg-cream-lift h1.truncate", user.username)
      assert has_element?(view, "#profile-header .w-24.h-24")
      assert has_element?(view, "#profile-stats", "Recipes")
      assert has_element?(view, "#profile-header button[phx-click='toggle-follow'].w-full")
      assert html |> String.split(~s(phx-click="toggle-follow")) |> length() == 2
      assert has_element?(view, "#profile-recipes h2", "Recipes")
      assert has_element?(view, "#profile-recipes h2 span", "Newest first")
      assert has_element?(view, "#profile-posts.grid.grid-cols-2")
      assert html |> String.split("aspect-[4/3]") |> length() == 3
      refute html =~ "overflow-x"
    end

    test "shows edit profile button for own profile", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/@#{user.username}")

      assert html =~ "Edit profile"
    end

    test "does not show edit profile button for other users", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(other_user)
        |> live(~p"/@#{user.username}")

      refute html =~ "Edit profile"
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

      assert path == "/feed"
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

    test "authenticated user can follow and unfollow another user", %{conn: conn} do
      user = user_fixture()
      viewer = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(viewer)
        |> live(~p"/@#{user.username}")

      # Follow the user. W246: one full-width Follow button in the header
      # card. Match on the button text without relying on exact whitespace.
      html = render_click(view, "toggle-follow")
      assert html =~ ~r/phx-click="toggle-follow"[^>]*>\s*Following/

      # Unfollow the user.
      html = render_click(view, "toggle-follow")
      assert html =~ ~r/phx-click="toggle-follow"[^>]*>\s*Follow/
    end

    test "displays follower and following counts", %{conn: conn} do
      user = user_fixture()
      follower = user_fixture()

      # Create a follow relationship
      TraysSocial.Accounts.follow_user(follower, user)

      {:ok, view, html} =
        conn
        |> log_in_user(follower)
        |> live(~p"/@#{user.username}")

      # Should show 1 follower
      assert html =~ "1"
      assert html =~ "follower"

      assert has_element?(
               view,
               "#profile-stats a[href='/@#{user.username}/followers']",
               "Followers"
             )
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

      assert html =~ "Your first recipe goes here."
      assert html =~ "Post a recipe"
    end

    test "shows empty posts state for other user with no posts", %{conn: conn} do
      user = user_fixture()

      {:ok, view, html} = live(conn, ~p"/@#{user.username}")

      assert html =~ "No recipes yet"

      assert has_element?(
               view,
               "#profile-recipes-empty",
               "When @#{user.username} posts a recipe, it shows up here."
             )
    end
  end

  describe "Authentication (D60)" do
    test "anonymous visitors are redirected to login", %{conn: conn} do
      user = user_fixture()
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/@#{user.username}")
      assert path =~ "/users/log-in"
    end
  end
end
