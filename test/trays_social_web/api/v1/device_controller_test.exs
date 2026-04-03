defmodule TraysSocialWeb.API.V1.DeviceControllerTest do
  use TraysSocialWeb.ConnCase, async: true

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

    test "is idempotent for nonexistent token", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/devices/nonexistent_token")

      assert %{"data" => %{"message" => "device unregistered"}} = json_response(conn, 200)
    end
  end
end
