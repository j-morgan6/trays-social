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
          password: "valid_password123",
          age_confirmation: true
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
          password: "valid_password123",
          age_confirmation: true
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
          password: "valid_password123",
          age_confirmation: true
        })

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Enum.any?(errors, fn e -> e["field"] == "username" end)
    end

    test "returns error for short password", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/auth/register", %{
          email: "new@example.com",
          username: "newuser",
          password: "short",
          age_confirmation: true
        })

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Enum.any?(errors, fn e -> e["field"] == "password" end)
    end

    test "returns error for missing params", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/auth/register", %{})

      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns error when age confirmation is missing", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/auth/register", %{
          email: "new@example.com",
          username: "newuser",
          password: "valid_password123"
        })

      assert %{"errors" => errors} = json_response(conn, 422)

      assert Enum.any?(errors, fn e ->
               e["field"] == "age_confirmation" and e["message"] =~ "13 or older"
             end)
    end

    test "returns error when age confirmation is false", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/auth/register", %{
          email: "new@example.com",
          username: "newuser",
          password: "valid_password123",
          age_confirmation: false
        })

      assert %{"errors" => errors} = json_response(conn, 422)

      assert Enum.any?(errors, fn e ->
               e["field"] == "age_confirmation" and e["message"] =~ "13 or older"
             end)
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

    test "returns 403 with structured suspended body for a suspended user", %{conn: conn} do
      user = suspended_user_fixture()

      conn =
        post(conn, ~p"/api/v1/auth/login", %{
          email: user.email,
          password: valid_user_password()
        })

      assert %{"errors" => [error]} = json_response(conn, 403)
      assert error["code"] == "suspended"
      assert error["message"] =~ "suspended"
      # Indefinite sentinel → API serializes suspended_until as nil so iOS
      # does not render a confusing year-9999 date.
      assert error["suspended_until"] == nil
    end

    test "returns 403 with ISO8601 suspended_until for a bounded suspension", %{conn: conn} do
      future = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)
      user = suspended_user_fixture(%{}, future)

      conn =
        post(conn, ~p"/api/v1/auth/login", %{
          email: user.email,
          password: valid_user_password()
        })

      assert %{"errors" => [error]} = json_response(conn, 403)
      assert error["code"] == "suspended"
      assert error["suspended_until"] == DateTime.to_iso8601(future)
    end
  end

  describe "POST /api/v1/auth/refresh-tokens (W105)" do
    setup :register_and_api_authenticate_user

    test "returns a refresh token bound to the authenticated user", %{conn: conn, user: user} do
      conn = post(conn, ~p"/api/v1/auth/refresh-tokens", %{})
      assert %{"data" => %{"refresh_token" => refresh}} = json_response(conn, 200)
      assert is_binary(refresh)

      # Exchange round-trips back to the same user.
      assert {:ok, {returned_user, _api_bearer}} =
               TraysSocial.Accounts.exchange_refresh_token(refresh)

      assert returned_user.id == user.id
    end

    test "requires authentication" do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/v1/auth/refresh-tokens", %{})

      assert json_response(conn, 401)
    end
  end

  describe "POST /api/v1/auth/biometric-exchange (W105)" do
    test "exchanges a valid refresh token for an API bearer", %{conn: conn} do
      user = TraysSocial.AccountsFixtures.user_fixture()
      refresh = TraysSocial.Accounts.generate_user_refresh_token(user)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/v1/auth/biometric-exchange", %{refresh_token: refresh})

      assert %{"data" => %{"token" => api_bearer, "user" => user_json}} = json_response(conn, 200)
      assert user_json["id"] == user.id

      assert auth_user = TraysSocial.Accounts.get_user_by_api_token(api_bearer)
      assert auth_user.id == user.id
    end

    test "returns 401 for an unknown refresh token", %{conn: conn} do
      bogus = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/v1/auth/biometric-exchange", %{refresh_token: bogus})

      assert json_response(conn, 401)
    end

    test "returns 422 when refresh_token param is missing", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/v1/auth/biometric-exchange", %{})

      assert %{"errors" => [%{"message" => "refresh_token is required"}]} =
               json_response(conn, 422)
    end

    test "returns 422 for empty refresh_token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/v1/auth/biometric-exchange", %{refresh_token: ""})

      assert %{"errors" => [%{"message" => "refresh_token is required"}]} =
               json_response(conn, 422)
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

    # D54: defense-in-depth — the route is gated by AuthPlug, so the
    # controller should never see a malformed Authorization header in
    # practice. These tests call the action directly to lock in that
    # logout is idempotent and never crashes on bad input.
    test "logout tolerates a missing Authorization header (D54)" do
      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_req_header("accept", "application/json")

      conn = TraysSocialWeb.API.V1.AuthController.logout(conn, %{})
      assert %{"data" => %{"message" => "logged out"}} = json_response(conn, 200)
    end

    test "logout tolerates a non-Bearer Authorization scheme (D54)" do
      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> Plug.Conn.put_req_header("authorization", "Basic dXNlcjpwYXNz")

      conn = TraysSocialWeb.API.V1.AuthController.logout(conn, %{})
      assert %{"data" => %{"message" => "logged out"}} = json_response(conn, 200)
    end

    test "logout tolerates a non-base64 Bearer token (D54)" do
      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> Plug.Conn.put_req_header("authorization", "Bearer not-valid-base64-!!!")

      conn = TraysSocialWeb.API.V1.AuthController.logout(conn, %{})
      assert %{"data" => %{"message" => "logged out"}} = json_response(conn, 200)
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

  describe "PUT /api/v1/auth/me" do
    setup :register_and_api_authenticate_user

    test "updates username", %{conn: conn} do
      conn = put(conn, ~p"/api/v1/auth/me", %{username: "newname"})

      assert %{"data" => %{"username" => "newname"}} = json_response(conn, 200)
    end

    test "updates bio", %{conn: conn} do
      conn = put(conn, ~p"/api/v1/auth/me", %{bio: "I love cooking"})

      assert %{"data" => %{"bio" => "I love cooking"}} = json_response(conn, 200)
    end

    test "returns error for invalid username", %{conn: conn} do
      conn = put(conn, ~p"/api/v1/auth/me", %{username: "ab"})

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Enum.any?(errors, fn e -> e["field"] == "username" end)
    end

    test "requires authentication", %{} do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put(~p"/api/v1/auth/me", %{bio: "test"})

      assert json_response(conn, 401)
    end
  end

  describe "DELETE /api/v1/auth/me" do
    setup :register_and_api_authenticate_user

    test "deletes account and revokes tokens", %{conn: conn, user: user, api_token: token} do
      conn = delete(conn, ~p"/api/v1/auth/me")

      assert %{"data" => %{"message" => "account deleted"}} = json_response(conn, 200)

      # Token should be revoked
      refute TraysSocial.Accounts.get_user_by_api_token(token)

      # User should be deleted
      assert_raise Ecto.NoResultsError, fn ->
        TraysSocial.Repo.get!(TraysSocial.Accounts.User, user.id)
      end
    end

    test "requires authentication", %{} do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> delete(~p"/api/v1/auth/me")

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
          password: "valid_password123",
          age_confirmation: true
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
