defmodule TraysSocialWeb.API.V1.AppleAuthTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.AccountsFixtures

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "POST /api/v1/auth/apple" do
    test "creates new user and returns token with needs_username", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/auth/apple", %{
          identity_token: "valid_apple_token",
          email: "apple@privaterelay.appleid.com"
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert is_binary(data["token"])
      assert data["needs_username"] == true
      assert data["user"]["email"] == "apple@privaterelay.appleid.com"
    end

    test "creates user with username when provided", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/auth/apple", %{
          identity_token: "valid_apple_token",
          email: "apple@privaterelay.appleid.com",
          username: "appleuser"
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["needs_username"] == false
      assert data["user"]["username"] == "appleuser"
    end

    test "returns existing user on subsequent sign-in", %{conn: conn} do
      # First sign-in creates user
      user = create_apple_user("existing_apple_user", "existing@apple.com")

      # Second sign-in finds existing user
      conn =
        post(conn, ~p"/api/v1/auth/apple", %{
          identity_token: "existing_apple_token"
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["user"]["id"] == user.id
    end

    test "returns 401 for invalid token", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/auth/apple", %{
          identity_token: "invalid_token"
        })

      assert %{"errors" => [%{"message" => "unauthorized"}]} = json_response(conn, 401)
    end

    test "returns 422 when identity_token missing", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/auth/apple", %{})

      assert %{"errors" => [%{"message" => "identity_token is required"}]} =
               json_response(conn, 422)
    end

    test "uses email from claims when not provided in params", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/auth/apple", %{
          identity_token: "valid_apple_token"
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert data["user"]["email"] == "apple@privaterelay.appleid.com"
    end
  end

  defp create_apple_user(apple_id, email) do
    {:ok, user} =
      %TraysSocial.Accounts.User{}
      |> Ecto.Changeset.change(%{
        apple_id: apple_id,
        email: email,
        username: "existingapple",
        confirmed_at: DateTime.utc_now(:second)
      })
      |> TraysSocial.Repo.insert()

    user
  end
end
