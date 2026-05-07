defmodule TraysSocialWeb.LegalControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  describe "GET /privacy" do
    test "returns 200 HTML with cache-control", %{conn: conn} do
      conn = get(conn, ~p"/privacy")

      assert conn.status == 200
      assert ["text/html" <> _] = get_resp_header(conn, "content-type")
      assert ["public, max-age=3600"] = get_resp_header(conn, "cache-control")
    end
  end

  describe "GET /terms" do
    test "returns 200 HTML with cache-control", %{conn: conn} do
      conn = get(conn, ~p"/terms")

      assert conn.status == 200
      assert ["text/html" <> _] = get_resp_header(conn, "content-type")
      assert ["public, max-age=3600"] = get_resp_header(conn, "cache-control")
    end
  end
end
