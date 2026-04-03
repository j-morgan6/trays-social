defmodule TraysSocialWeb.API.V1.UserControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  setup :register_and_api_authenticate_user

  describe "GET /api/v1/users/:username" do
    test "returns user profile with counts", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/v1/users/#{user.username}")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == user.id
      assert data["username"] == user.username
      assert is_integer(data["post_count"])
      assert is_integer(data["follower_count"])
      assert is_integer(data["following_count"])
      assert data["followed_by_current_user"] == false
    end

    test "shows followed_by_current_user correctly", %{conn: conn, user: user} do
      other = user_fixture()
      TraysSocial.Accounts.follow_user(user, other)

      conn = get(conn, ~p"/api/v1/users/#{other.username}")

      assert %{"data" => %{"followed_by_current_user" => true}} = json_response(conn, 200)
    end

    test "returns 404 for nonexistent user", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/users/nobody999")

      assert json_response(conn, 404)
    end
  end

  describe "GET /api/v1/users/:username/posts" do
    test "returns user posts", %{conn: conn, user: user} do
      post_fixture(%{user_id: user.id})

      conn = get(conn, ~p"/api/v1/users/#{user.username}/posts")

      assert %{"data" => posts, "cursor" => _} = json_response(conn, 200)
      assert length(posts) == 1
    end

    test "returns 404 for nonexistent user", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/users/nobody999/posts")

      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/users/:username/follow" do
    test "follows a user", %{conn: conn} do
      other = user_fixture()

      conn = post(conn, ~p"/api/v1/users/#{other.username}/follow")

      assert %{"data" => %{"message" => "followed"}} = json_response(conn, 200)
    end

    test "follow is idempotent", %{conn: conn} do
      other = user_fixture()

      post(conn, ~p"/api/v1/users/#{other.username}/follow")
      conn = post(conn, ~p"/api/v1/users/#{other.username}/follow")

      assert json_response(conn, 200)
    end

    test "returns 403 for following yourself", %{conn: conn, user: user} do
      conn = post(conn, ~p"/api/v1/users/#{user.username}/follow")

      assert json_response(conn, 403)
    end
  end

  describe "DELETE /api/v1/users/:username/follow" do
    test "unfollows a user", %{conn: conn} do
      other = user_fixture()
      TraysSocial.Accounts.follow_user(conn.assigns[:current_user] || user_fixture(), other)

      conn = delete(conn, ~p"/api/v1/users/#{other.username}/follow")

      assert %{"data" => %{"message" => "unfollowed"}} = json_response(conn, 200)
    end

    test "unfollow is idempotent", %{conn: conn} do
      other = user_fixture()

      conn = delete(conn, ~p"/api/v1/users/#{other.username}/follow")

      assert json_response(conn, 200)
    end
  end
end
