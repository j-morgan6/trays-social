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

  test "GET / redirects authenticated visitors to the feed (W120)", %{conn: conn} do
    user = user_fixture()

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/")

    assert redirected_to(conn) == ~p"/feed"
  end
end
