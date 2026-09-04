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

  test "GET / describes Trays Plus and links to Terms and Privacy (W182)", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ "Trays Plus"
    # Price and trial must match App Store Connect and the FAQ exactly.
    assert html =~ "$3.99 per month or $29.99 per year"
    assert html =~ "7-day free trial"
    # A paid section has to reach the documents that govern the purchase.
    assert html =~ ~s|href="/terms"|
    assert html =~ ~s|href="/privacy"|
    # North star: Plus bundles utility, never recipe content.
    assert html =~ "Every recipe on Trays is free to read, cook, and save"
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
