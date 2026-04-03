defmodule TraysSocialWeb.API.V1.FeedControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  setup :register_and_api_authenticate_user

  describe "GET /api/v1/feed" do
    test "returns posts in reverse chronological order", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/feed")

      assert %{"data" => posts, "cursor" => _cursor} = json_response(conn, 200)
      assert is_list(posts)
    end

    test "returns posts with all expected fields", %{conn: conn, user: user} do
      post_fixture(%{user_id: user.id})

      conn = get(conn, ~p"/api/v1/feed")

      assert %{"data" => [post | _]} = json_response(conn, 200)
      assert Map.has_key?(post, "id")
      assert Map.has_key?(post, "type")
      assert Map.has_key?(post, "caption")
      assert Map.has_key?(post, "like_count")
      assert Map.has_key?(post, "liked_by_current_user")
      assert Map.has_key?(post, "user")
      assert Map.has_key?(post, "photos")
      assert Map.has_key?(post, "ingredients")
      assert Map.has_key?(post, "cooking_steps")
      assert Map.has_key?(post, "tags")
    end

    test "returns cursor for pagination", %{conn: conn, user: user} do
      post_fixture(%{user_id: user.id})

      conn = get(conn, ~p"/api/v1/feed")

      assert %{"cursor" => cursor} = json_response(conn, 200)
      assert is_binary(cursor)
    end

    test "requires authentication", %{} do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get(~p"/api/v1/feed")

      assert json_response(conn, 401)
    end
  end
end
