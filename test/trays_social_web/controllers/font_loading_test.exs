defmodule TraysSocialWeb.FontLoadingTest do
  # W240: the CSP allows fonts from 'self' only, so the root layout must
  # preload the self-hosted Nunito and never link Google Fonts (which the
  # CSP would silently block).
  use TraysSocialWeb.ConnCase, async: true

  test "pages preload the self-hosted Nunito and link no Google Fonts", %{conn: conn} do
    html = conn |> get(~p"/users/log-in") |> html_response(200)

    assert html =~ ~s(href="/fonts/nunito-latin-wght-normal.woff2")
    assert html =~ ~s(rel="preload")
    assert html =~ ~s(as="font")
    refute html =~ "fonts.googleapis.com"
    refute html =~ "fonts.gstatic.com"
  end
end
