defmodule TraysSocialWeb.FeedLive.IndexTest do
  use TraysSocialWeb.ConnCase

  import Phoenix.LiveViewTest
  import TraysSocial.PostsFixtures
  import TraysSocial.AccountsFixtures

  # All Feed routes require an authenticated session (D60). Each describe
  # below sets up a logged-in "viewer" so existing tests continue to exercise
  # the rendered feed; the separate "Authentication" describe at the bottom
  # asserts the redirect behavior for anonymous visitors.
  describe "Index" do
    setup %{conn: conn} do
      viewer = user_fixture()
      %{conn: log_in_user(conn, viewer), viewer: viewer}
    end

    test "displays empty state when no posts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Feed"
      assert html =~ "No posts yet"
    end

    test "lists all posts", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Feed"
      assert html =~ post.caption
      assert html =~ user.username
    end

    test "shows create post link when logged in", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/")

      # Editorial header now exposes the create flow via an amber
      # "New recipe" pill that links to /posts/new.
      assert html =~ "New recipe"
      assert html =~ ~s|href="/posts/new"|
    end

    test "receives real-time updates for new posts", %{conn: conn} do
      user = user_fixture()
      {:ok, view, _html} = live(conn, ~p"/")

      # Create a new post and broadcast it
      post = post_fixture(user_id: user.id)
      Phoenix.PubSub.broadcast(TraysSocial.PubSub, "posts:new", {:new_post, post})

      # Give LiveView time to process the message
      :timer.sleep(100)

      # Verify the post appears in the feed
      html = render(view)
      assert html =~ post.caption
      assert html =~ user.username
    end

    test "load-more event is a no-op when has_more is false", %{conn: conn} do
      user = user_fixture()
      _post = post_fixture(user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/")

      # With fewer than @page_size (20) posts, has_more should be false
      # load-more should be a no-op
      html = render_click(view, "load-more")
      assert html =~ "all caught up"
    end

    test "authenticated user can toggle like on a post in feed", %{conn: conn} do
      owner = user_fixture()
      liker = user_fixture()
      post = post_fixture(user_id: owner.id)

      {:ok, view, html} =
        conn
        |> log_in_user(liker)
        |> live(~p"/")

      # Post starts with 0 likes
      assert html =~ post.caption

      # Like the post
      html = render_click(view, "toggle-like", %{"post-id" => to_string(post.id)})
      assert html =~ "1"

      # Unlike the post
      html = render_click(view, "toggle-like", %{"post-id" => to_string(post.id)})
      assert html =~ "0"
    end

    test "open-drawer and close-drawer events work", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/")

      # Open the recipe drawer
      html = render_click(view, "open-drawer", %{"id" => to_string(post.id)})
      assert html =~ "Recipe"

      # Close the recipe drawer
      _html = render_click(view, "close-drawer")
      # Should not crash; page still renders
      html = render(view)
      assert html =~ post.caption
    end

    test "next-photo and prev-photo events do not crash", %{conn: conn} do
      user = user_fixture()

      post =
        post_fixture(
          user_id: user.id,
          post_photos: [
            %{url: "/uploads/feed_photo1.jpg", position: 0},
            %{url: "/uploads/feed_photo2.jpg", position: 1}
          ]
        )

      {:ok, view, html} = live(conn, ~p"/")

      # Initial render shows both photo carousel arrows
      assert html =~ "next-photo"
      assert html =~ "prev-photo"

      # Navigate forward - should not crash
      render_click(view, "next-photo", %{"post-id" => to_string(post.id)})
      html = render(view)
      assert html =~ post.caption

      # Navigate backward - should not crash
      render_click(view, "prev-photo", %{"post-id" => to_string(post.id)})
      html = render(view)
      assert html =~ post.caption
    end

    test "shows end-of-feed message when no more posts", %{conn: conn} do
      user = user_fixture()
      _post = post_fixture(user_id: user.id)

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "all caught up"
    end

    test "receives real-time like count updates via PubSub", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/")

      # Broadcast a like update
      Phoenix.PubSub.broadcast(
        TraysSocial.PubSub,
        "posts:likes",
        {:like_updated, post.id, 5}
      )

      :timer.sleep(100)

      html = render(view)
      assert html =~ "5"
    end

    test "shows global feed nudge for logged-in user without follows", %{conn: conn} do
      user = user_fixture()
      _post = post_fixture(user_id: user.id)

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/")

      assert html =~ "Showing all recent posts"
      assert html =~ "Follow people to personalize your feed"
    end

    test "like_updated for a post not in feed is a no-op", %{conn: conn} do
      user = user_fixture()
      _post = post_fixture(user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/")

      # Broadcast a like update for a non-existent post ID
      Phoenix.PubSub.broadcast(
        TraysSocial.PubSub,
        "posts:likes",
        {:like_updated, -999, 10}
      )

      :timer.sleep(100)

      # The view should still render without error
      html = render(view)
      assert html =~ "Feed"
    end

    test "next-photo for a post not in feed is a no-op", %{conn: conn} do
      user = user_fixture()
      _post = post_fixture(user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/")

      # Navigate photo for a non-existent post ID
      html = render_click(view, "next-photo", %{"post-id" => "-999"})
      assert html =~ "Feed"
    end

    test "prev-photo for a post not in feed is a no-op", %{conn: conn} do
      user = user_fixture()
      _post = post_fixture(user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/")

      # Navigate photo backward for a non-existent post ID
      html = render_click(view, "prev-photo", %{"post-id" => "-999"})
      assert html =~ "Feed"
    end

    test "toggle-like for a post not in posts_map is a no-op", %{conn: conn} do
      user = user_fixture()
      _post = post_fixture(user_id: user.id)

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/")

      # Toggle like for a non-existent post
      html = render_click(view, "toggle-like", %{"post-id" => "-999"})
      assert html =~ "Feed"
    end

    test "photo navigation on a single-photo post is a no-op", %{conn: conn} do
      user = user_fixture()
      # Post with only the main photo_url (no extra post_photos)
      post = post_fixture(user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/")

      # next-photo on a single-photo post should not change anything
      render_click(view, "next-photo", %{"post-id" => to_string(post.id)})
      html = render(view)
      assert html =~ post.caption
    end

    test "shows personalized feed for user with follows", %{conn: conn} do
      poster = user_fixture()
      follower = user_fixture()
      other_poster = user_fixture()

      followed_post = post_fixture(user_id: poster.id, caption: "Followed user post")
      _other_post = post_fixture(user_id: other_poster.id, caption: "Other user post")

      TraysSocial.Accounts.follow_user(follower, poster)

      {:ok, _view, html} =
        conn
        |> log_in_user(follower)
        |> live(~p"/")

      assert html =~ followed_post.caption
      # Nudge should not appear for personalized feeds
      refute html =~ "Follow people to personalize your feed"
    end
  end

  describe "Authentication (D60)" do
    test "anonymous visitors are redirected to login", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/")
      assert path =~ "/users/log-in"
    end
  end
end
