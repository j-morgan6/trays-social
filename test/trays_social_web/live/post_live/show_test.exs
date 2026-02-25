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
      assert html =~ TraysSocial.Uploads.ImageProcessor.large_url(post.photo_url)
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
  end
end
