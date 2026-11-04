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
        "Canada and the United States",
        # W215: what iOS 1.1.0 declares in PrivacyInfo.xcprivacy. Name, feedback,
        # recipe opens and diagnostics must stay disclosed, with their retention.
        "may also share your name",
        "to suggest a username",
        "In-app feedback you send us",
        "the subject and message you write, plus your app version, OS version and device model",
        "along with your app version, OS version and device model",
        "Recipe opens: when you are signed in",
        "Recipe opens are not used for analytics or ads",
        "MetricKit",
        "linked to your signed-in account",
        "In-app feedback: kept while your account is active",
        "Recipe opens: kept while your account is active",
        "with no fixed deletion schedule, and deleted when you delete your account",
        "Reports sent while you were signed out are not linked to any account",
        "If you do not share your name",
        "store your device",
        "Server error reports: when a request to our servers fails",
        # D120: error reports are redacted before storage and age out at 30 days.
        "we remove passwords, sign-in and security tokens, and sign-in cookies and headers",
        "we remove email addresses from the fields that normally hold them",
        "the details of each failed request are deleted 30 days after it happens",
        "Server error reports are deleted on their own 30-day schedule",
        "section 10 lists what happens to each kind of data when you do",
        # The no-tracking promises the App Privacy label relies on.
        "do not run third-party analytics",
        "do not collect advertising IDs",
        "do not track you across other apps or websites"
      ]

      for phrase <- required do
        assert body =~ phrase, "expected /privacy body to contain #{inspect(phrase)}"
      end
    end

    test "no longer says diagnostics or error reports survive account deletion", %{conn: conn} do
      body = conn |> get(~p"/privacy") |> html_response(200)

      for stale <- [
            "the diagnostic report itself may be kept",
            "They are not removed when you delete your account",
            "the recipient address and subject"
          ] do
        refute body =~ stale, "expected /privacy body not to contain #{inspect(stale)}"
      end
    end

    test "no longer describes diagnostics as basic error events", %{conn: conn} do
      conn = get(conn, ~p"/privacy")

      refute response(conn, 200) =~ "Basic error events"
    end

    test "does not describe purchase or subscription data as collected", %{conn: conn} do
      conn = get(conn, ~p"/privacy")
      body = response(conn, 200)

      # W215: those disclosures ship with the Plus release, alongside the
      # manifest's purchase history declaration.
      for phrase <- ~w(purchase subscription StoreKit) do
        refute body =~ ~r/#{phrase}/i, "expected /privacy not to mention #{phrase}"
      end
    end

    test "renders the frontmatter version and date, matching the CHANGELOG", %{conn: conn} do
      conn = get(conn, ~p"/privacy")
      body = response(conn, 200)

      source = :trays_social |> Application.app_dir("priv/legal/privacy.md") |> File.read!()
      [_, date] = Regex.run(~r/^effective_date: (\S+)$/m, source)
      [_, version] = Regex.run(~r/^version: (\S+)$/m, source)

      assert body =~ "Effective #{date}"
      assert body =~ "v#{version}"

      changelog = :trays_social |> Application.app_dir("priv/legal/CHANGELOG.md") |> File.read!()

      [_, latest_version, latest_date] =
        Regex.run(~r/^## Privacy Policy v(\S+) — (\S+)$/m, changelog)

      assert {latest_version, latest_date} == {version, date}
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

    # W183: an auto-renewable subscription needs its billing terms discoverable
    # from the document the paywall links to. Before v1.2 the only payment
    # wording in the whole document was Apple's warranty boilerplate at 16.4.
    test "covers the Trays Plus subscription and billing disclosures", %{conn: conn} do
      conn = get(conn, ~p"/terms")
      body = response(conn, 200)

      required = [
        "Trays Plus subscriptions and billing",
        # Price and period. The App Store's displayed local price governs.
        "US$3.99",
        "US$29.99",
        "displayed price is the price that governs",
        # Auto-renewal and the cancellation deadline.
        "renews automatically",
        "at least 24 hours before the end of the current period",
        # Trial, and what happens if it is not cancelled.
        "7-day free trial",
        # Cancellation route — Apple, not us.
        "Cancel Subscription",
        "account.apple.com",
        # Refunds are Apple's, and we do not limit statutory rights.
        "refunds are handled by Apple",
        "reportaproblem.apple.com",
        # Price-change notice.
        "increase the price"
      ]

      for phrase <- required do
        assert body =~ phrase, "expected /terms body to contain #{inspect(phrase)}"
      end
    end

    test "does not promise an in-app cancellation control it does not have",
         %{conn: conn} do
      conn = get(conn, ~p"/terms")
      body = response(conn, 200)

      # Trays cannot cancel or refund on the user's behalf. The document has to
      # say so, because the App Store is the only cancellation route.
      assert body =~ "not inside the Trays app"
      assert body =~ "We cannot issue, approve, or deny a refund"
    end

    # W210: Earmark passes HTML comments through to the served page, so an
    # internal note in terms.md is readable by anyone who views the page
    # source. Section 17 stays visible; the W183 draft note above it must not.
    test "serves section 17 without the internal W183 draft note", %{conn: conn} do
      conn = get(conn, ~p"/terms")
      body = response(conn, 200)

      assert body =~ "Trays Plus subscriptions and billing"
      refute body =~ "W183 DRAFT", "/terms must not serve the W183 draft note"
      refute body =~ "LEGAL REVIEW BEFORE THIS DOCUMENT GOES LIVE"
      refute body =~ "<!--", "/terms must not serve internal HTML comments from terms.md"
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

    # W215: the FAQ summary must not understate what Privacy Policy v1.3 discloses.
    test "lists what we collect in line with the privacy policy", %{conn: conn} do
      body = conn |> get(~p"/faq") |> response(200)

      assert body =~ "feedback you send us"
      assert body =~ "which recipes you open"
      assert body =~ "crash and performance reports"
      refute body =~ "basic server logs"
    end

    # W182: the FAQ shipped at v1.0 asserting there were no subscriptions and
    # no advertising. Both became false — the Privacy Policy has described
    # advertising since v1.2, and Trays Plus is a real subscription. These
    # sentences must never come back.
    test "no longer denies that subscriptions or advertising exist", %{conn: conn} do
      conn = get(conn, ~p"/faq")
      body = response(conn, 200)

      for phrase <- ["no advertising", "no subscriptions", "no in-app purchases"] do
        refute body =~ phrase, "/faq must not claim #{inspect(phrase)}"
      end
    end

    # W211: Plus ships in a later iOS release and nothing can be bought today.
    # The FAQ is compiled at build time, so it cannot follow the runtime
    # paid_tier flag; it must say plainly that Plus is not for sale yet.
    test "FAQ says Trays Plus is not available to buy yet", %{conn: conn} do
      conn = get(conn, ~p"/faq")
      body = response(conn, 200)

      assert body =~ "It is not available to buy yet."
      assert body =~ "Trays Plus is not available to buy"

      for phrase <- ["$3.99", "$29.99", "7-day free trial", "per month"] do
        refute body =~ phrase, "/faq must not advertise #{inspect(phrase)} before Plus launches"
      end
    end

    test "answers the Trays Plus questions App Review expects", %{conn: conn} do
      conn = get(conn, ~p"/faq")
      body = response(conn, 200)

      required = [
        # What it is, and that it never gates recipe content.
        "What is Trays Plus?",
        "never gates recipes",
        # W211: Plus is not on sale yet, so the cost answer names no price.
        "What does Trays Plus cost?",
        # Restore and cancel are both App Review requirements for an
        # auto-renewable subscription.
        "How do I restore a purchase?",
        "Restore purchases",
        "How do I cancel Trays Plus?",
        "Subscriptions"
      ]

      for phrase <- required do
        assert body =~ phrase, "expected /faq body to contain #{inspect(phrase)}"
      end
    end
  end
end
