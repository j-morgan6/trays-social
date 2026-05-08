defmodule TraysSocialWeb.Plugs.RequireAdminTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.AccountsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.Scope

  describe "plug call/2" do
    test "passes through when current_scope.user is admin", %{conn: conn} do
      user = user_fixture()
      {:ok, admin} = Accounts.set_admin(user, true)

      conn =
        conn
        |> Plug.Conn.assign(:current_scope, %Scope{user: admin})
        |> TraysSocialWeb.Plugs.RequireAdmin.call([])

      refute conn.halted
    end

    test "halts with 404 when user is not admin", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> Plug.Conn.assign(:current_scope, %Scope{user: user})
        |> TraysSocialWeb.Plugs.RequireAdmin.call([])

      assert conn.halted
      assert conn.status == 404
    end

    test "halts with 404 when current_scope is missing", %{conn: conn} do
      conn = TraysSocialWeb.Plugs.RequireAdmin.call(conn, [])

      assert conn.halted
      assert conn.status == 404
    end
  end
end
