defmodule TraysSocialWeb.PageControllerTest do
  use TraysSocialWeb.ConnCase

  test "GET / shows feed", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Feed"
    assert html_response(conn, 200) =~ "Feed"
  end
end
