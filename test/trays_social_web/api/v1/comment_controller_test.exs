defmodule TraysSocialWeb.API.V1.CommentControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  setup :register_and_api_authenticate_user

  describe "GET /api/v1/posts/:post_id/comments" do
    test "returns empty list for post with no comments", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})

      conn = get(conn, ~p"/api/v1/posts/#{post.id}/comments")

      assert %{"data" => [], "cursor" => nil} = json_response(conn, 200)
    end

    test "returns comments for a post", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})
      {:ok, _comment} = TraysSocial.Posts.create_comment(post, user, %{body: "Great recipe!"})

      conn = get(conn, ~p"/api/v1/posts/#{post.id}/comments")

      assert %{"data" => [comment]} = json_response(conn, 200)
      assert comment["body"] == "Great recipe!"
      assert comment["user"]["username"] == user.username
      assert comment["id"]
      assert comment["inserted_at"]
    end

    test "supports cursor-based pagination", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})

      for i <- 1..3 do
        {:ok, _} = TraysSocial.Posts.create_comment(post, user, %{body: "Comment #{i}"})
      end

      conn1 = get(conn, ~p"/api/v1/posts/#{post.id}/comments?cursor=")

      assert %{"data" => comments, "cursor" => cursor} = json_response(conn1, 200)
      assert length(comments) == 3
      assert cursor != nil
    end

    test "returns 404 for nonexistent post", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/posts/999999/comments")

      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/posts/:post_id/comments" do
    test "creates a comment", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})

      conn =
        post(conn, ~p"/api/v1/posts/#{post.id}/comments", %{body: "Looks delicious!"})

      assert %{"data" => comment} = json_response(conn, 201)
      assert comment["body"] == "Looks delicious!"
      assert comment["user"]["username"] == user.username
    end

    test "creates notification for post author", %{conn: conn} do
      other_user = user_fixture()
      post = post_fixture(%{user_id: other_user.id})

      post(conn, ~p"/api/v1/posts/#{post.id}/comments", %{body: "Nice!"})

      notifications = TraysSocial.Notifications.list_notifications(other_user.id)
      assert Enum.any?(notifications, &(&1.type == "comment"))
    end

    test "does not create self-notification", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})

      post(conn, ~p"/api/v1/posts/#{post.id}/comments", %{body: "My own comment"})

      notifications = TraysSocial.Notifications.list_notifications(user.id)
      refute Enum.any?(notifications, &(&1.type == "comment"))
    end

    test "returns 422 with invalid data", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})

      conn = post(conn, ~p"/api/v1/posts/#{post.id}/comments", %{body: ""})

      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns 404 for nonexistent post", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/posts/999999/comments", %{body: "test"})

      assert json_response(conn, 404)
    end
  end

  describe "DELETE /api/v1/comments/:id" do
    test "deletes own comment", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})
      {:ok, comment} = TraysSocial.Posts.create_comment(post, user, %{body: "To delete"})

      conn = delete(conn, ~p"/api/v1/comments/#{comment.id}")

      assert %{"data" => _} = json_response(conn, 200)
    end

    test "cannot delete another user's comment", %{conn: conn} do
      other_user = user_fixture()
      post = post_fixture(%{user_id: other_user.id})
      {:ok, comment} = TraysSocial.Posts.create_comment(post, other_user, %{body: "Not yours"})

      conn = delete(conn, ~p"/api/v1/comments/#{comment.id}")

      assert json_response(conn, 403)
    end

    test "returns 404 for nonexistent comment", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/comments/999999")

      assert json_response(conn, 404)
    end
  end
end
