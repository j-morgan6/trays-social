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

  describe "admin LiveView coverage (W264)" do
    # Every LiveView in the TraysSocialWeb.Admin namespace must re-check
    # is_admin per event, and the RequireAdmin moduledoc must name it, so a
    # new admin page cannot quietly ship with the mount-only check. The
    # third-party /admin dashboards (LiveDashboard, ErrorTracker) live
    # outside this namespace and are not covered here.
    test "every admin LiveView mounts :ensure_admin_each_event and the moduledoc names it" do
      modules =
        TraysSocialWeb.Router
        |> Phoenix.Router.routes()
        |> Enum.filter(&Map.has_key?(&1.metadata, :phoenix_live_view))
        |> Enum.map(&elem(&1.metadata.phoenix_live_view, 0))
        |> Enum.filter(&String.starts_with?(inspect(&1), "TraysSocialWeb.Admin."))
        |> Enum.uniq()

      assert TraysSocialWeb.Admin.ReportsLive in modules
      assert TraysSocialWeb.Admin.EmailEventsLive in modules

      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} =
        Code.fetch_docs(TraysSocialWeb.Plugs.RequireAdmin)

      for module <- modules do
        hook_ids = Enum.map(module.__live__()[:lifecycle].mount, & &1.id)

        assert {TraysSocialWeb.Plugs.RequireAdmin, :ensure_admin} in hook_ids,
               "#{inspect(module)} does not mount :ensure_admin"

        assert {TraysSocialWeb.Plugs.RequireAdmin, :ensure_admin_each_event} in hook_ids,
               "#{inspect(module)} does not mount :ensure_admin_each_event"

        short_name = module |> Module.split() |> List.last()

        assert moduledoc =~ short_name,
               "the RequireAdmin moduledoc does not name #{short_name}"
      end
    end
  end
end
