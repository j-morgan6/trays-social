defmodule TraysSocialWeb.PostLive.ShowTest do
  use TraysSocialWeb.ConnCase

  import Phoenix.LiveViewTest
  import TraysSocial.PostsFixtures
  import TraysSocial.AccountsFixtures

  describe "Show" do
    test "displays post with all details", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, _view, html} = live(conn, ~p"/posts/#{post.id}")

      assert html =~ post.user.username
      assert html =~ post.caption
      assert html =~ "#{post.cooking_time_minutes} minutes"
      assert html =~ post.photo_url
    end

    test "shows delete button for post owner", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/posts/#{post.id}")

      assert html =~ "Delete Post"
    end

    test "does not show delete button for non-owner", %{conn: conn} do
      owner = user_fixture()
      other_user = user_fixture()
      post = post_fixture(user_id: owner.id)

      {:ok, _view, html} =
        conn
        |> log_in_user(other_user)
        |> live(~p"/posts/#{post.id}")

      refute html =~ "Delete Post"
    end

    test "deletes post when owner clicks delete button", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/posts/#{post.id}")

      assert view
             |> element("button", "Delete Post")
             |> render_click()

      assert_redirect(view, ~p"/")

      # Verify post was soft deleted
      deleted_post = TraysSocial.Repo.get(TraysSocial.Posts.Post, post.id)
      assert deleted_post.deleted_at != nil
    end

    test "back to feed link works", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/posts/#{post.id}")

      assert view
             |> element("a", "Back to feed")
             |> render_click()

      assert_redirect(view, ~p"/")
    end

    test "authenticated user can toggle like on a post", %{conn: conn} do
      owner = user_fixture()
      liker = user_fixture()
      post = post_fixture(user_id: owner.id)

      {:ok, view, html} =
        conn
        |> log_in_user(liker)
        |> live(~p"/posts/#{post.id}")

      # Post starts with 0 likes
      assert html =~ "0"

      # Like the post
      html = render_click(view, "toggle-like")
      assert html =~ "1"

      # Unlike the post
      html = render_click(view, "toggle-like")
      assert html =~ "0"
    end

    test "unauthenticated user clicking like is redirected to login", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/posts/#{post.id}")

      render_click(view, "toggle-like")
      assert_redirect(view, ~p"/users/log-in")
    end

    test "authenticated user can add a comment", %{conn: conn} do
      owner = user_fixture()
      commenter = user_fixture()
      post = post_fixture(user_id: owner.id)

      {:ok, view, html} =
        conn
        |> log_in_user(commenter)
        |> live(~p"/posts/#{post.id}")

      # Comment form is visible for authenticated users
      assert html =~ "Add a comment..."

      # Submit a comment
      html =
        view
        |> form("form", comment: %{body: "Looks delicious!"})
        |> render_submit()

      assert html =~ "Looks delicious!"
      assert html =~ commenter.username
    end

    test "unauthenticated user sees login prompt instead of comment form", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, _view, html} = live(conn, ~p"/posts/#{post.id}")

      refute html =~ "Add a comment..."
      assert html =~ "Log in"
      assert html =~ "to leave a comment"
    end

    test "comment author can delete their own comment", %{conn: conn} do
      owner = user_fixture()
      commenter = user_fixture()
      post = post_fixture(user_id: owner.id)
      comment = comment_fixture(post, commenter, %{body: "Comment to delete"})

      {:ok, view, html} =
        conn
        |> log_in_user(commenter)
        |> live(~p"/posts/#{post.id}")

      assert html =~ "Comment to delete"

      # Delete the comment
      render_click(view, "delete-comment", %{"id" => to_string(comment.id)})

      html = render(view)
      refute html =~ "Comment to delete"
    end

    test "non-author cannot delete someone else's comment", %{conn: conn} do
      owner = user_fixture()
      commenter = user_fixture()
      other_user = user_fixture()
      post = post_fixture(user_id: owner.id)
      _comment = comment_fixture(post, commenter, %{body: "Not my comment"})

      {:ok, _view, html} =
        conn
        |> log_in_user(other_user)
        |> live(~p"/posts/#{post.id}")

      # The comment is visible but the delete button should not be shown
      assert html =~ "Not my comment"
      # The Delete button is only rendered for the comment's own author
      refute html =~ "delete-comment"
    end

    test "update-comment-body event updates the comment body assign", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/posts/#{post.id}")

      # The event should update without error
      render_click(view, "update-comment-body", %{"value" => "typing..."})
      html = render(view)
      assert html =~ "typing..."
    end

    test "photo navigation with single photo is a no-op", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/posts/#{post.id}")

      # With a single photo, next/prev should be no-ops (no crash)
      render_click(view, "next-photo")
      render_click(view, "prev-photo")

      # Page still renders correctly
      html = render(view)
      assert html =~ post.caption
    end

    test "photo navigation with multiple photos cycles through them", %{conn: conn} do
      user = user_fixture()

      post =
        post_fixture(
          user_id: user.id,
          post_photos: [
            %{url: "/uploads/photo1.jpg", position: 0},
            %{url: "/uploads/photo2.jpg", position: 1},
            %{url: "/uploads/photo3.jpg", position: 2}
          ]
        )

      {:ok, view, html} = live(conn, ~p"/posts/#{post.id}")

      # Should start at photo 0, showing counter "1 / 3"
      assert html =~ "1 / 3"

      # Navigate forward
      html = render_click(view, "next-photo")
      assert html =~ "2 / 3"

      # Navigate forward again
      html = render_click(view, "next-photo")
      assert html =~ "3 / 3"

      # Wrap around to first
      html = render_click(view, "next-photo")
      assert html =~ "1 / 3"

      # Navigate backward (wraps to last)
      html = render_click(view, "prev-photo")
      assert html =~ "3 / 3"
    end

    test "non-owner cannot delete post", %{conn: conn} do
      owner = user_fixture()
      other_user = user_fixture()
      post = post_fixture(user_id: owner.id)

      {:ok, view, _html} =
        conn
        |> log_in_user(other_user)
        |> live(~p"/posts/#{post.id}")

      # Manually send the delete event (even though button is hidden)
      render_click(view, "delete")

      # User stays on the page (no redirect), post is still visible
      html = render(view)
      assert html =~ post.caption

      # Verify the post was NOT deleted
      db_post = TraysSocial.Repo.get(TraysSocial.Posts.Post, post.id)
      assert is_nil(db_post.deleted_at)
    end

    test "unauthenticated user trying to comment is redirected", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/posts/#{post.id}")

      render_click(view, "add-comment", %{"comment" => %{"body" => "test"}})
      assert_redirect(view, ~p"/users/log-in")
    end

    test "displays comment count", %{conn: conn} do
      owner = user_fixture()
      commenter = user_fixture()
      post = post_fixture(user_id: owner.id)
      _comment = comment_fixture(post, commenter, %{body: "A comment"})

      # Reload post to get updated comment_count
      {:ok, _view, html} = live(conn, ~p"/posts/#{post.id}")

      assert html =~ "Comments (1)"
      assert html =~ "A comment"
    end
  end
end
