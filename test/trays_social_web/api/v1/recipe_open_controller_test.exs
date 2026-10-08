defmodule TraysSocialWeb.API.V1.RecipeOpenControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.Posts.RecipeOpen
  alias TraysSocial.Repo

  setup :register_and_api_authenticate_user

  describe "POST /api/v1/posts/:id/open" do
    test "records an open", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user_fixture().id})

      assert %{"data" => %{"opened" => true}} =
               conn |> post(~p"/api/v1/posts/#{post.id}/open") |> json_response(200)

      assert Repo.get_by(RecipeOpen, user_id: user.id, post_id: post.id)
    end

    test "404 for a missing post", %{conn: conn} do
      assert conn |> post(~p"/api/v1/posts/999999999/open") |> json_response(404)
    end

    test "404 for a non-numeric id", %{conn: conn} do
      assert conn |> post("/api/v1/posts/abc/open") |> json_response(404)
    end

    test "404 for an id beyond the bigint range", %{conn: conn} do
      assert conn |> post("/api/v1/posts/99999999999999999999/open") |> json_response(404)
    end

    test "404 when the author blocked the viewer", %{conn: conn, user: user} do
      author = user_fixture()
      post = post_fixture(%{user_id: author.id})
      {:ok, _} = Accounts.block_user(author.id, user.id)

      assert conn |> post(~p"/api/v1/posts/#{post.id}/open") |> json_response(404)
      refute Repo.get_by(RecipeOpen, user_id: user.id, post_id: post.id)
    end

    test "401 without a token" do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/v1/posts/1/open")

      assert json_response(conn, 401)
    end
  end
end
