defmodule TraysSocialWeb.API.V1.IosDiagnosticControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  alias TraysSocial.Diagnostics

  @valid_body %{
    "payload_type" => "diagnostic",
    "payload" => %{"crashDiagnostics" => []},
    "app_version" => "1.0.0",
    "os_version" => "17.5",
    "device_model" => "iPhone15,3"
  }

  setup :register_and_api_authenticate_user

  describe "POST /api/v1/ios_diagnostics" do
    test "stores a valid payload and returns 201", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/ios_diagnostics", @valid_body)

      assert %{"data" => %{"id" => id, "received_at" => received_at}} = json_response(conn, 201)
      assert is_integer(id)
      assert is_binary(received_at)

      record = Diagnostics.get_payload!(id)
      assert record.payload_type == "diagnostic"
      assert record.payload == %{"crashDiagnostics" => []}
      assert record.app_version == "1.0.0"
    end

    test "correlates the payload with the authenticated user", %{conn: conn, user: user} do
      conn = post(conn, ~p"/api/v1/ios_diagnostics", @valid_body)
      assert %{"data" => %{"id" => id}} = json_response(conn, 201)

      assert Diagnostics.get_payload!(id).user_id == user.id
    end

    test "accepts an arbitrarily-shaped inner payload without inner validation", %{conn: conn} do
      # The whole point: Apple changes the schema and we must not reject
      # a future iOS payload because its shape is novel.
      body = %{@valid_body | "payload" => %{"futureField" => 42, "list" => [1, 2, 3]}}

      assert %{"data" => %{"id" => _}} = post(conn, ~p"/api/v1/ios_diagnostics", body) |> json_response(201)
    end

    test "returns 422 when payload_type is missing", %{conn: conn} do
      body = Map.delete(@valid_body, "payload_type")
      conn = post(conn, ~p"/api/v1/ios_diagnostics", body)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert is_list(errors)
    end

    test "returns 422 when payload is missing", %{conn: conn} do
      body = Map.delete(@valid_body, "payload")
      conn = post(conn, ~p"/api/v1/ios_diagnostics", body)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert is_list(errors)
    end

    test "returns 422 when payload_type is not in the allowed set", %{conn: conn} do
      body = %{@valid_body | "payload_type" => "telemetry"}
      conn = post(conn, ~p"/api/v1/ios_diagnostics", body)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Enum.any?(errors, fn e -> e["field"] == "payload_type" end)
    end

    test "returns 401 when unauthenticated" do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/v1/ios_diagnostics", @valid_body)

      assert json_response(conn, 401)
    end
  end
end
