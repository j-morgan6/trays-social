defmodule TraysSocialWeb.API.RateLimitPlugTest do
  use TraysSocialWeb.ConnCase, async: false

  alias TraysSocialWeb.API.RateLimitPlug

  setup %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> Map.put(:request_path, "/api/v1/auth/login")

    {:ok, conn: conn}
  end

  describe "call/2" do
    test "allows requests under the limit", %{conn: conn} do
      opts = RateLimitPlug.init(max_requests: 3, interval_ms: 60_000)

      conn = RateLimitPlug.call(conn, opts)

      refute conn.halted
    end

    test "blocks requests over the limit", %{conn: conn} do
      opts = RateLimitPlug.init(max_requests: 2, interval_ms: 60_000)

      # Use a unique path to avoid interference from other tests
      conn = Map.put(conn, :request_path, "/api/v1/auth/test-rate-limit-#{System.unique_integer([:positive])}")

      _conn1 = RateLimitPlug.call(conn, opts)
      _conn2 = RateLimitPlug.call(conn, opts)
      conn3 = RateLimitPlug.call(conn, opts)

      assert conn3.halted
      assert conn3.status == 429
      assert get_resp_header(conn3, "retry-after") == ["60"]
      assert Jason.decode!(conn3.resp_body) == %{"errors" => [%{"message" => "too many requests"}]}
    end

    test "includes Retry-After header in 429 response", %{conn: conn} do
      opts = RateLimitPlug.init(max_requests: 1, interval_ms: 120_000)

      conn = Map.put(conn, :request_path, "/api/v1/auth/test-retry-#{System.unique_integer([:positive])}")

      _conn1 = RateLimitPlug.call(conn, opts)
      conn2 = RateLimitPlug.call(conn, opts)

      assert conn2.halted
      assert get_resp_header(conn2, "retry-after") == ["120"]
    end
  end
end
