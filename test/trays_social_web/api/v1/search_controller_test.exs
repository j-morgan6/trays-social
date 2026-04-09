defmodule TraysSocialWeb.API.V1.SearchControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  setup :register_and_api_authenticate_user

  describe "GET /api/v1/search" do
    test "returns matching posts by caption", %{conn: conn, user: user} do
      post_fixture(%{user_id: user.id, caption: "Amazing pasta recipe"})
      post_fixture(%{user_id: user.id, caption: "Chicken stir fry"})

      conn = get(conn, ~p"/api/v1/search?q=pasta")

      assert %{"data" => %{"posts" => posts, "users" => _}} = json_response(conn, 200)
      assert length(posts) == 1
      assert hd(posts)["caption"] =~ "pasta"
    end

    test "returns matching users by username", %{conn: conn} do
      user_fixture(%{username: "chef_pasta_king"})

      conn = get(conn, ~p"/api/v1/search?q=pasta")

      assert %{"data" => %{"users" => users}} = json_response(conn, 200)
      assert length(users) == 1
      assert hd(users)["username"] == "chef_pasta_king"
    end

    test "filters by max_cooking_time", %{conn: conn, user: user} do
      post_fixture(%{user_id: user.id, type: "recipe", cooking_time_minutes: 15, caption: "Quick meal"})
      post_fixture(%{user_id: user.id, type: "recipe", cooking_time_minutes: 60, caption: "Slow meal"})

      conn = get(conn, ~p"/api/v1/search?max_cooking_time=30")

      assert %{"data" => %{"posts" => posts}} = json_response(conn, 200)
      assert length(posts) == 1
      assert hd(posts)["cooking_time_minutes"] == 15
    end

    test "returns empty results for no match", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/search?q=zzzznonexistent")

      assert %{"data" => %{"posts" => [], "users" => []}} = json_response(conn, 200)
    end

    test "handles empty query", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/search")

      assert %{"data" => %{"posts" => _, "users" => _}} = json_response(conn, 200)
    end
  end
end
