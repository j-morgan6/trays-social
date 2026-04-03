defmodule TraysSocialWeb.API.V1.AuthControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.AccountsFixtures

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "POST /api/v1/auth/register" do
    test "creates user and returns token", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/auth/register", %{
          email: "new@example.com",
          username: "newuser",
          password: "valid_password123"
        })

      assert %{"data" => %{"token" => token, "user" => user}} = json_response(conn, 201)
      assert is_binary(token)
      assert user["email"] == "new@example.com"
      assert user["username"] == "newuser"
      refute Map.has_key?(user, "hashed_password")
    end

    test "returns error for duplicate email", %{conn: conn} do
      user = user_fixture()

      conn =
        post(conn, ~p"/api/v1/auth/register", %{
          email: user.email,
          username: "otheruser",
          password: "valid_password123"
        })

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Enum.any?(errors, fn e -> e["field"] == "email" end)
    end

    test "returns error for duplicate username", %{conn: conn} do
      user = user_fixture()

      conn =
        post(conn, ~p"/api/v1/auth/register", %{
          email: "other@example.com",
          username: user.username,
          password: "valid_password123"
        })

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Enum.any?(errors, fn e -> e["field"] == "username" end)
    end

    test "returns error for short password", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/auth/register", %{
          email: "new@example.com",
          username: "newuser",
          password: "short"
        })

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Enum.any?(errors, fn e -> e["field"] == "password" end)
    end

    test "returns error for missing params", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/auth/register", %{})

      assert %{"errors" => _} = json_response(conn, 422)
    end
  end

  describe "POST /api/v1/auth/login" do
    test "returns token for valid credentials", %{conn: conn} do
      user = user_fixture()

      conn =
        post(conn, ~p"/api/v1/auth/login", %{
          email: user.email,
          password: valid_user_password()
        })

      assert %{"data" => %{"token" => token, "user" => user_data}} = json_response(conn, 200)
      assert is_binary(token)
      assert user_data["id"] == user.id
    end

    test "returns 401 for wrong password", %{conn: conn} do
      user = user_fixture()

      conn =
        post(conn, ~p"/api/v1/auth/login", %{
          email: user.email,
          password: "wrong_password123"
        })

      assert %{"errors" => [%{"message" => "unauthorized"}]} = json_response(conn, 401)
    end

    test "returns 401 for nonexistent email", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/auth/login", %{
          email: "nobody@example.com",
          password: "any_password123"
        })

      assert %{"errors" => [%{"message" => "unauthorized"}]} = json_response(conn, 401)
    end

    test "returns error for missing params", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/auth/login", %{})

      assert %{"errors" => _} = json_response(conn, 422)
    end
  end

  describe "DELETE /api/v1/auth/logout" do
    setup :register_and_api_authenticate_user

    test "revokes the token", %{conn: conn, api_token: token} do
      # Verify token works before logout
      assert TraysSocial.Accounts.get_user_by_api_token(token)

      conn = delete(conn, ~p"/api/v1/auth/logout")

      assert %{"data" => %{"message" => "logged out"}} = json_response(conn, 200)

      # Token should be revoked
      refute TraysSocial.Accounts.get_user_by_api_token(token)
    end

    test "requires authentication", %{} do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> delete(~p"/api/v1/auth/logout")

      assert json_response(conn, 401)
    end
  end

  describe "GET /api/v1/auth/me" do
    setup :register_and_api_authenticate_user

    test "returns current user", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/v1/auth/me")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == user.id
      assert data["email"] == user.email
      assert data["username"] == user.username
      assert data["needs_username"] == false
    end

    test "requires authentication", %{} do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get(~p"/api/v1/auth/me")

      assert json_response(conn, 401)
    end
  end

  describe "full register then authenticate flow" do
    test "can register and use returned token", %{conn: conn} do
      # Register
      conn1 =
        post(conn, ~p"/api/v1/auth/register", %{
          email: "flow@example.com",
          username: "flowuser",
          password: "valid_password123"
        })

      assert %{"data" => %{"token" => token}} = json_response(conn1, 201)

      # Use token to hit me endpoint
      conn2 =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/v1/auth/me")

      assert %{"data" => %{"username" => "flowuser"}} = json_response(conn2, 200)
    end
  end
end
