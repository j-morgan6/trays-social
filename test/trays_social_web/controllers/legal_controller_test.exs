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
        # EU/UK Article 27 is handled by territory restriction (CA + US only),
        # not an appointed representative — guard both the legal hook and the
        # territory statement so neither can be silently dropped.
        "Article 27 of the GDPR",
        "Canada and the United States"
      ]

      for phrase <- required do
        assert body =~ phrase, "expected /privacy body to contain #{inspect(phrase)}"
      end
    end

    test "links the ads-choices page and keeps the no-ad-cookies statement", %{conn: conn} do
      conn = get(conn, ~p"/privacy")
      body = response(conn, 200)

      # W159: the CCPA do-not-sell section now points at the functional
      # preference control instead of calling the link a no-op.
      assert body =~ "/privacy/ads-choices"
      # This sentence must survive verbatim — the preference cookie is
      # disclosed separately and is not an advertising cookie.
      assert body =~ "We do not set advertising or analytics cookies"
    end
  end

  describe "GET /privacy/ads-choices" do
    test "returns 200 HTML, uncacheable, with the preference form", %{conn: conn} do
      conn = get(conn, ~p"/privacy/ads-choices")

      assert conn.status == 200
      assert ["text/html" <> _] = get_resp_header(conn, "content-type")
      assert ["private, no-store"] = get_resp_header(conn, "cache-control")

      body = response(conn, 200)
      assert body =~ "No opt-out preference is set."
      assert body =~ ~s|action="/privacy/ads-choices"|
      assert body =~ ~s|name="choice"|
      assert body =~ ~s|value="opt_out"|
      assert body =~ "Global Privacy Control"
    end

    test "shows the opted-out status and the opt-in form when the cookie is set",
         %{conn: conn} do
      conn =
        conn
        |> put_req_cookie("trays_ads_opt_out", "1")
        |> get(~p"/privacy/ads-choices")

      body = response(conn, 200)
      assert body =~ "You are opted out of advertising-related cookies."
      assert body =~ ~s|value="opt_in"|
    end
  end

  describe "POST /privacy/ads-choices" do
    test "opt_out sets the preference cookie (readable by JS) and redirects",
         %{conn: conn} do
      conn = post(conn, ~p"/privacy/ads-choices", %{"choice" => "opt_out"})

      assert redirected_to(conn) == ~p"/privacy/ads-choices"

      cookie = conn.resp_cookies["trays_ads_opt_out"]
      assert cookie.value == "1"
      assert cookie.max_age == 31_536_000
      assert cookie.same_site == "Lax"
      # http_only: false is deliberate — the AdSlot JS hook reads this cookie
      # before requesting any ad script, and the value carries no identifier.
      assert cookie.http_only == false
    end

    test "opt_in deletes the preference cookie and redirects", %{conn: conn} do
      conn =
        conn
        |> put_req_cookie("trays_ads_opt_out", "1")
        |> post(~p"/privacy/ads-choices", %{"choice" => "opt_in"})

      assert redirected_to(conn) == ~p"/privacy/ads-choices"
      assert %{max_age: 0} = conn.resp_cookies["trays_ads_opt_out"]
    end

    test "unknown choice redirects without touching the cookie", %{conn: conn} do
      conn = post(conn, ~p"/privacy/ads-choices", %{"choice" => "whatever"})

      assert redirected_to(conn) == ~p"/privacy/ads-choices"
      refute Map.has_key?(conn.resp_cookies, "trays_ads_opt_out")
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
