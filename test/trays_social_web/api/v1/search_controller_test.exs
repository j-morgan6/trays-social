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

    # D107: query + tag together crashed with Ecto's double-distinct error.
    test "query with tag filter returns 200 and a cursor", %{conn: conn, user: user} do
      post_fixture(%{
        user_id: user.id,
        caption: "pasta primavera",
        post_tags: [%{tag: "dinner"}]
      })

      conn = get(conn, ~p"/api/v1/search?q=pasta&tag=dinner")

      assert %{"data" => %{"posts" => [post]}, "cursor" => cursor} = json_response(conn, 200)
      assert post["caption"] == "pasta primavera"
      assert is_binary(cursor)
    end

    test "malformed cursor degrades to page 1 instead of 500", %{conn: conn, user: user} do
      post_fixture(%{user_id: user.id, caption: "pasta bake"})

      bad_cursors = [
        "not-base64!",
        Base.url_encode64("abc:def", padding: false),
        Base.url_encode64("99999999999999999999:2026-01-01T00:00:00Z", padding: false)
      ]

      for bad <- bad_cursors do
        conn = get(conn, ~p"/api/v1/search?q=pasta&cursor=#{bad}")
        assert %{"data" => %{"posts" => [_]}} = json_response(conn, 200)
      end
    end
  end
end
