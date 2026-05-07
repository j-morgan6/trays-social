defmodule TraysSocialWeb.LegalControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  describe "GET /privacy" do
    test "returns 200 HTML with cache-control", %{conn: conn} do
      conn = get(conn, ~p"/privacy")

      assert conn.status == 200
      assert ["text/html" <> _] = get_resp_header(conn, "content-type")
      assert ["public, max-age=3600"] = get_resp_header(conn, "cache-control")
    end

    test "contains all required privacy phrases", %{conn: conn} do
      conn = get(conn, ~p"/privacy")
      body = response(conn, 200)

      required = [
        "1001366752 Ontario Inc.",
        "support@trays.app",
        "Sign in with Apple",
        "Tigris",
        "the sole Director",
        "Do Not Sell or Share My Personal Information",
        "Sensitive Personal Information",
        "GDPR Article 27"
      ]

      for phrase <- required do
        assert body =~ phrase, "expected /privacy body to contain #{inspect(phrase)}"
      end
    end
  end

  describe "GET /terms" do
    test "returns 200 HTML with cache-control", %{conn: conn} do
      conn = get(conn, ~p"/terms")

      assert conn.status == 200
      assert ["text/html" <> _] = get_resp_header(conn, "content-type")
      assert ["public, max-age=3600"] = get_resp_header(conn, "cache-control")
    end

    test "contains all required TOS phrases", %{conn: conn} do
      conn = get(conn, ~p"/terms")
      body = response(conn, 200)

      required = [
        "1001366752 Ontario Inc.",
        "support@trays.app",
        "binding individual arbitration",
        "Quebec",
        "cook at your own risk",
        "third-party beneficiaries",
        "Digital Millennium Copyright Act",
        "US$100"
      ]

      for phrase <- required do
        assert body =~ phrase, "expected /terms body to contain #{inspect(phrase)}"
      end
    end
  end
end
