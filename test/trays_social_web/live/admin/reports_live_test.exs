defmodule TraysSocialWeb.Admin.ReportsLiveTest do
  @moduledoc """
  D55 regression: the admin ReportsLive used socket.assigns.current_user
  but UserAuth populates :current_scope, so any handle_event that touched
  the field crashed with KeyError — resolved_by_id / removed_by_id never
  got written and the moderation audit trail was silently empty.

  Also locks in the on_mount(:require_admin) gate so a future
  live_session refactor that bypasses the router pipeline can't open the
  view to non-admins.
  """
  use TraysSocialWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.Reports
  alias TraysSocial.Reports.Report

  defp admin_fixture do
    user = user_fixture()
    {:ok, admin} = Accounts.set_admin(user, true)
    admin
  end

  defp open_report_fixture(reporter) do
    {:ok, report} =
      Reports.create_report(reporter, %{
        target_type: "post",
        target_id: 1,
        reason: "spam"
      })

    report
  end

  test "non-admin gets a 404 from the router pipeline (D55)", %{conn: conn} do
    # RequireAdmin plug halts with 404 before the LiveView mounts, so the
    # check fires at the pipeline level. The on_mount hook on the LiveView
    # is defense-in-depth for live_session routes that don't go through
    # the same plug pipeline.
    user = user_fixture()

    conn = conn |> log_in_user(user) |> get(~p"/admin/reports")
    assert conn.status == 404
  end

  test "admin clicking Resolve writes their user_id into resolved_by_id (D55)", %{conn: conn} do
    admin = admin_fixture()
    reporter = user_fixture()
    report = open_report_fixture(reporter)

    {:ok, view, _html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/admin/reports")

    view
    |> element(
      "button[phx-click=\"resolve\"][phx-value-id=\"#{report.id}\"][phx-value-status=\"resolved\"]"
    )
    |> render_click()

    reloaded = TraysSocial.Repo.get!(Report, report.id)
    assert reloaded.status == "resolved"
    assert reloaded.resolved_by_id == admin.id
  end
end
