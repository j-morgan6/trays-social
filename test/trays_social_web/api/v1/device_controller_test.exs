defmodule TraysSocialWeb.API.V1.DeviceControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.AccountsFixtures

  setup :register_and_api_authenticate_user

  describe "POST /api/v1/devices" do
    test "registers a device token", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/devices", %{token: "apns_token_abc123"})

      assert %{"data" => %{"message" => "device registered"}} = json_response(conn, 201)
    end

    test "upserts same token for same user", %{conn: conn} do
      post(conn, ~p"/api/v1/devices", %{token: "apns_token_upsert"})
      conn = post(conn, ~p"/api/v1/devices", %{token: "apns_token_upsert"})

      assert %{"data" => %{"message" => "device registered"}} = json_response(conn, 201)
    end

    test "accepts platform parameter", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/devices", %{token: "apns_token_platform", platform: "ios"})

      assert json_response(conn, 201)
    end

    test "returns error when token missing", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/devices", %{})

      assert %{"errors" => [%{"field" => "token"}]} = json_response(conn, 422)
    end

    test "requires authentication", %{} do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/v1/devices", %{token: "test"})

      assert json_response(conn, 401)
    end
  end

  describe "DELETE /api/v1/devices/:token" do
    test "unregisters a device token", %{conn: conn} do
      post(conn, ~p"/api/v1/devices", %{token: "apns_token_to_delete"})
      conn = delete(conn, ~p"/api/v1/devices/apns_token_to_delete")

      assert %{"data" => %{"message" => "device unregistered"}} = json_response(conn, 200)
    end

    test "returns 404 for nonexistent token (D43, IDOR-safe)", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/devices/nonexistent_token")

      assert %{"errors" => [%{"message" => "device not found"}]} = json_response(conn, 404)
    end

    test "cannot delete another user's token (D43)", %{conn: conn} do
      # Register a token for user A out of band, then attempt delete as the
      # authenticated test user (B). Must respond identically to the
      # nonexistent-token case so an attacker can't enumerate ownership.
      other_user = user_fixture()
      {:ok, _} = TraysSocial.Notifications.register_device(other_user.id, "victim_token", "ios")

      conn = delete(conn, ~p"/api/v1/devices/victim_token")

      assert %{"errors" => [%{"message" => "device not found"}]} = json_response(conn, 404)

      # The victim's row is untouched.
      assert TraysSocial.Repo.get_by(TraysSocial.Notifications.DeviceToken, token: "victim_token")
    end

    test "cannot hijack another user's token via POST (D43)", %{conn: conn, user: user} do
      # User A registers a token. User B (authenticated as `conn`) tries to
      # register the same token — must NOT silently rebind it to B. Must
      # also respond identically to the unknown-token case (404).
      other_user = user_fixture()
      {:ok, %{user_id: a_id}} = TraysSocial.Notifications.register_device(other_user.id, "shared_token", "ios")
      refute a_id == user.id

      conn = post(conn, ~p"/api/v1/devices", %{token: "shared_token"})

      assert %{"errors" => [%{"message" => "device not found"}]} = json_response(conn, 404)

      # And the existing row is still bound to user A.
      row = TraysSocial.Repo.get_by(TraysSocial.Notifications.DeviceToken, token: "shared_token")
      assert row.user_id == other_user.id
    end
  end
end
