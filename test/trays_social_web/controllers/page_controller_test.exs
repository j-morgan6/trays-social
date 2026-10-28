defmodule TraysSocialWeb.PageControllerTest do
  use TraysSocialWeb.ConnCase

  import TraysSocial.AccountsFixtures

  test "GET / renders the public landing page for anonymous visitors (W120)", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    # On-brand landing copy, not the Phoenix default template.
    assert html =~ "For home cooks"
    assert html =~ "recipe-sharing community"
    refute html =~ "mix phx.server"
  end

  # W211: the Plus section names a price and a trial only while paid_tier is
  # on. The flag is global app env, so restore it after every test (this
  # module is not async).
  describe "GET / Trays Plus section" do
    setup do
      original = Application.get_env(:trays_social, :features, [])
      on_exit(fn -> Application.put_env(:trays_social, :features, original) end)
      %{original: original}
    end

    test "with paid_tier on shows $3.99 and $29.99 (W182, W211)", %{
      conn: conn,
      original: original
    } do
      Application.put_env(:trays_social, :features, Keyword.put(original, :paid_tier, true))

      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "Trays Plus"
      # Price and trial must match App Store Connect exactly.
      assert html =~ "$3.99 per month or $29.99 per year"
      assert html =~ "7-day free trial"
      assert html =~ "Trays Plus is sold through the App Store"
      refute html =~ "coming in a future update"
      # A paid section has to reach the documents that govern the purchase.
      assert html =~ ~s|href="/terms"|
      assert html =~ ~s|href="/privacy"|
      # North star: Plus bundles utility, never recipe content.
      assert html =~ "Every recipe on Trays is free to read, cook, and save"
    end

    test "with paid_tier off shows 'coming soon' and no prices (W211)", %{
      conn: conn,
      original: original
    } do
      Application.put_env(:trays_social, :features, Keyword.delete(original, :paid_tier))

      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "Trays Plus is coming in a future update."
      assert html =~ "It is not available to buy yet."

      for phrase <- ["$3.99", "$29.99", "7-day", "free trial", "per month", "per year"] do
        refute html =~ phrase,
               "landing page must not show #{inspect(phrase)} while paid_tier is off"
      end

      refute html =~ "Trays Plus is sold through the App Store"
      # The recipes-stay-free framing stays whatever the flag says.
      assert html =~ "Recipes stay free."
      assert html =~ "Every recipe on Trays is free to read, cook, and save"
    end

    test "treats a paid_tier value other than literal true as off (W211)", %{
      conn: conn,
      original: original
    } do
      Application.put_env(:trays_social, :features, Keyword.put(original, :paid_tier, "true"))

      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "Trays Plus is coming in a future update."
      refute html =~ "$3.99"
    end
  end

  test "GET / no longer claims the feed has no ads (W182)", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    # The hero previously said posts land in feeds "with no ads and no
    # algorithm deciding what you see". The no-algorithm half is still true
    # and stays; the no-ads half is not, now that the ad slots exist.
    refute html =~ "no ads and no algorithm"
    assert html =~ "algorithm deciding what you see"
  end

  test "GET / redirects authenticated visitors to the feed (W120)", %{conn: conn} do
    user = user_fixture()

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/")

    assert redirected_to(conn) == ~p"/feed"
  end
end
