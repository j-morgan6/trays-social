defmodule TraysSocialWeb.API.V1.PostControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  setup :register_and_api_authenticate_user

  describe "GET /api/v1/posts/:id" do
    test "returns post with all associations", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})

      conn = get(conn, ~p"/api/v1/posts/#{post.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == post.id
      assert data["type"] == "recipe"
      assert is_list(data["ingredients"])
      assert is_list(data["cooking_steps"])
      assert data["user"]["id"] == user.id
    end

    test "returns 404 for nonexistent post", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/posts/999999")

      assert json_response(conn, 404)
    end

    test "returns 404 for deleted post", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})
      TraysSocial.Posts.delete_post(post)

      conn = get(conn, ~p"/api/v1/posts/#{post.id}")

      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/posts" do
    test "creates a recipe post", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/posts", %{
          photo_url: "/uploads/test.jpg",
          caption: "My recipe",
          cooking_time_minutes: 30,
          type: "recipe",
          ingredients: [%{name: "Salt", quantity: "1 tsp"}],
          cooking_steps: [%{description: "Mix it", order: 0}]
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert data["caption"] == "My recipe"
      assert data["type"] == "recipe"
    end

    test "creates a simple post", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/posts", %{
          photo_url: "/uploads/test.jpg",
          caption: "Just food",
          type: "post"
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert data["type"] == "post"
    end

    test "returns error for missing required fields", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/posts", %{caption: "no photo"})

      assert json_response(conn, 422)
    end
  end

  describe "DELETE /api/v1/posts/:id" do
    test "soft-deletes own post", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})

      conn = delete(conn, ~p"/api/v1/posts/#{post.id}")

      assert %{"data" => %{"message" => "post deleted"}} = json_response(conn, 200)
    end

    test "returns 403 for other user's post", %{conn: conn} do
      other_user = user_fixture()
      post = post_fixture(%{user_id: other_user.id})

      conn = delete(conn, ~p"/api/v1/posts/#{post.id}")

      assert json_response(conn, 403)
    end

    test "returns 404 for nonexistent post", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/posts/999999")

      assert json_response(conn, 404)
    end
  end
end
