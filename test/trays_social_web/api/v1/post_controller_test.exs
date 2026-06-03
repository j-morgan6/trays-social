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

  describe "PATCH /api/v1/posts/:id" do
    test "owner can update caption, cooking time, servings, and photo", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})

      conn =
        patch(conn, ~p"/api/v1/posts/#{post.id}", %{
          caption: "Updated caption",
          cooking_time_minutes: 99,
          servings: 6,
          photo_url: "https://images.unsplash.com/photo-updated?w=800"
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == post.id
      assert data["caption"] == "Updated caption"
      assert data["cooking_time_minutes"] == 99
      assert data["servings"] == 6
      assert [%{"url" => "https://images.unsplash.com/photo-updated?w=800"}] = data["photos"]
    end

    test "a partial update leaves omitted fields (and the required photo_url) intact",
         %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})

      conn = patch(conn, ~p"/api/v1/posts/#{post.id}", %{caption: "Just the caption"})

      assert %{"data" => data} = json_response(conn, 200)
      assert data["caption"] == "Just the caption"
      assert data["cooking_time_minutes"] == 42
    end

    test "ownership and type are immutable — user_id/type in the body are ignored",
         %{conn: conn, user: user} do
      other_user = user_fixture()
      post = post_fixture(%{user_id: user.id})

      conn =
        patch(conn, ~p"/api/v1/posts/#{post.id}", %{
          caption: "Still mine",
          user_id: other_user.id,
          type: "tip"
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["user"]["id"] == user.id
      assert data["type"] == "recipe"
    end

    test "returns 403 for another user's post", %{conn: conn} do
      other_user = user_fixture()
      post = post_fixture(%{user_id: other_user.id})

      conn = patch(conn, ~p"/api/v1/posts/#{post.id}", %{caption: "hijack"})

      assert json_response(conn, 403)
    end

    test "returns 404 for a nonexistent post", %{conn: conn} do
      conn = patch(conn, ~p"/api/v1/posts/999999", %{caption: "ghost"})

      assert json_response(conn, 404)
    end

    test "returns 404 for a soft-deleted post", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})
      {:ok, _} = TraysSocial.Posts.delete_post(post)

      conn = patch(conn, ~p"/api/v1/posts/#{post.id}", %{caption: "back from the dead"})

      assert json_response(conn, 404)
    end

    test "returns 422 for invalid attrs", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})

      conn =
        patch(conn, ~p"/api/v1/posts/#{post.id}", %{caption: String.duplicate("x", 501)})

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Enum.any?(errors, &(&1["field"] == "caption"))
    end
  end
end
