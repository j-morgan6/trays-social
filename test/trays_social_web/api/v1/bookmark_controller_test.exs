defmodule TraysSocialWeb.API.V1.BookmarkControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  setup :register_and_api_authenticate_user

  describe "POST /api/v1/bookmarks/:post_id" do
    test "bookmarks a post", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})

      conn = post(conn, ~p"/api/v1/bookmarks/#{post.id}")

      assert %{"data" => %{"message" => "saved to tray"}} = json_response(conn, 201)
    end

    test "duplicate bookmark returns error", %{conn: conn, user: user} do
      post_record = post_fixture(%{user_id: user.id})
      TraysSocial.Posts.create_bookmark(user.id, post_record.id)

      conn = post(conn, ~p"/api/v1/bookmarks/#{post_record.id}")

      assert json_response(conn, 422)
    end

    test "returns 404 for nonexistent post", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/bookmarks/999999")

      assert json_response(conn, 404)
    end
  end

  describe "DELETE /api/v1/bookmarks/:post_id" do
    test "removes a bookmark", %{conn: conn, user: user} do
      post_record = post_fixture(%{user_id: user.id})
      TraysSocial.Posts.create_bookmark(user.id, post_record.id)

      conn = delete(conn, ~p"/api/v1/bookmarks/#{post_record.id}")

      assert %{"data" => %{"message" => "removed from tray"}} = json_response(conn, 200)
    end

    test "returns 404 for non-bookmarked post", %{conn: conn, user: user} do
      post_record = post_fixture(%{user_id: user.id})

      conn = delete(conn, ~p"/api/v1/bookmarks/#{post_record.id}")

      assert json_response(conn, 404)
    end
  end

  describe "GET /api/v1/bookmarks" do
    test "returns empty list when no bookmarks", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/bookmarks")

      assert %{"data" => [], "cursor" => nil} = json_response(conn, 200)
    end

    test "returns bookmarked posts", %{conn: conn, user: user} do
      post_record = post_fixture(%{user_id: user.id})
      TraysSocial.Posts.create_bookmark(user.id, post_record.id)

      conn = get(conn, ~p"/api/v1/bookmarks")

      assert %{"data" => [post]} = json_response(conn, 200)
      assert post["id"] == post_record.id
      assert post["bookmarked_by_current_user"] == true
    end

    test "does not return deleted posts", %{conn: conn, user: user} do
      post_record = post_fixture(%{user_id: user.id})
      TraysSocial.Posts.create_bookmark(user.id, post_record.id)
      TraysSocial.Posts.delete_post(post_record)

      conn = get(conn, ~p"/api/v1/bookmarks")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "bookmarked_by_current_user in feed" do
    test "feed includes bookmark status", %{conn: conn, user: user} do
      post_record = post_fixture(%{user_id: user.id})
      TraysSocial.Posts.create_bookmark(user.id, post_record.id)

      conn = get(conn, ~p"/api/v1/feed")

      assert %{"data" => posts} = json_response(conn, 200)
      assert Enum.any?(posts, &(&1["bookmarked_by_current_user"] == true))
    end
  end
end
