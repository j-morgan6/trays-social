defmodule TraysSocialWeb.PageControllerTest do
  use TraysSocialWeb.ConnCase

  import TraysSocial.AccountsFixtures

  test "GET / shows feed for an authenticated user", %{conn: conn} do
    user = user_fixture()

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/")

    assert html_response(conn, 200) =~ "Feed"
  end

  test "GET / redirects anonymous visitors to login (D60)", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) =~ "/users/log-in"
  end
end
