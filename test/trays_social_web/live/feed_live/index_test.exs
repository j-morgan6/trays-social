defmodule TraysSocialWeb.FeedLive.IndexTest do
  use TraysSocialWeb.ConnCase

  import Phoenix.LiveViewTest
  import TraysSocial.PostsFixtures
  import TraysSocial.AccountsFixtures

  describe "Index" do
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

      assert html =~ "Create Post"
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
  end
end
