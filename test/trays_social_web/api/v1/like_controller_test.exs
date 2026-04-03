defmodule TraysSocialWeb.API.V1.LikeControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  setup :register_and_api_authenticate_user

  describe "POST /api/v1/posts/:post_id/like" do
    test "likes a post", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})

      conn = post(conn, ~p"/api/v1/posts/#{post.id}/like")

      assert %{"data" => %{"message" => "liked"}} = json_response(conn, 200)
    end

    test "liking is idempotent", %{conn: conn, user: user} do
      post_record = post_fixture(%{user_id: user.id})

      post(conn, ~p"/api/v1/posts/#{post_record.id}/like")
      conn = post(conn, ~p"/api/v1/posts/#{post_record.id}/like")

      assert json_response(conn, 200)
    end

    test "returns 404 for nonexistent post", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/posts/999999/like")

      assert json_response(conn, 404)
    end
  end

  describe "DELETE /api/v1/posts/:post_id/like" do
    test "unlikes a post", %{conn: conn, user: user} do
      post_record = post_fixture(%{user_id: user.id})
      TraysSocial.Posts.like_post(post_record, user)

      conn = delete(conn, ~p"/api/v1/posts/#{post_record.id}/like")

      assert %{"data" => %{"message" => "unliked"}} = json_response(conn, 200)
    end

    test "unlike is idempotent", %{conn: conn, user: user} do
      post_record = post_fixture(%{user_id: user.id})

      conn = delete(conn, ~p"/api/v1/posts/#{post_record.id}/like")

      assert json_response(conn, 200)
    end
  end
end
