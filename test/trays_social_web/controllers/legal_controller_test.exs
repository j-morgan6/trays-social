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

  describe "GET /community-guidelines" do
    test "returns 200 HTML with cache-control", %{conn: conn} do
      conn = get(conn, ~p"/community-guidelines")

      assert conn.status == 200
      assert ["text/html" <> _] = get_resp_header(conn, "content-type")
      assert ["public, max-age=3600"] = get_resp_header(conn, "cache-control")
    end

    test "contains the expected sections", %{conn: conn} do
      conn = get(conn, ~p"/community-guidelines")
      body = response(conn, 200)

      required = [
        "Community Guidelines",
        "What we love to see",
        # Earmark's smart-typography pass renders apostrophes as U+2019 curly quotes.
        "What’s not allowed",
        "Harassment, hate, or threats",
        "Spam, scams, and manipulation",
        "Cooking-specific judgment calls",
        "How moderation works",
        "Appeals",
        "support@trays.app",
        # Contact-section-unique phrase so dropping the Contact section breaks
        # this test (support@trays.app alone also appears in Appeals).
        "questions about these guidelines"
      ]

      for phrase <- required do
        assert body =~ phrase, "expected /community-guidelines body to contain #{inspect(phrase)}"
      end
    end
  end

  describe "GET /faq" do
    test "is public and returns 200 HTML with cache-control", %{conn: conn} do
      conn = get(conn, ~p"/faq")

      assert conn.status == 200
      assert ["text/html" <> _] = get_resp_header(conn, "content-type")
      assert ["public, max-age=3600"] = get_resp_header(conn, "cache-control")
    end

    test "covers every question and links to support", %{conn: conn} do
      conn = get(conn, ~p"/faq")
      body = response(conn, 200)

      required = [
        "What is Trays?",
        "Who is it for?",
        "Is it free?",
        "Do you have ads?",
        "Do you track me?",
        "How do I report a problem?",
        "How do I delete my account?",
        "Where does my data live?",
        "How do I contact support?",
        "support@trays.app"
      ]

      for phrase <- required do
        assert body =~ phrase, "expected /faq body to contain #{inspect(phrase)}"
      end
    end
  end
end
