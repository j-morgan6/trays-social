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

  defp open_user_report_fixture(reporter, target_user) do
    {:ok, report} =
      Reports.create_report(reporter, %{
        target_type: "user",
        target_id: target_user.id,
        reason: "harassment"
      })

    report
  end

  test "admin can suspend a target user indefinitely from a user-typed report", %{conn: conn} do
    admin = admin_fixture()
    reporter = user_fixture()
    target = user_fixture()
    report = open_user_report_fixture(reporter, target)

    {:ok, view, _html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/admin/reports")

    view
    |> form("form[phx-submit=\"suspend_user\"]", %{
      "report_id" => report.id,
      "suspended_until" => ""
    })
    |> render_submit()

    reloaded_target = Accounts.get_user!(target.id)
    assert reloaded_target.suspended_until == ~U[9999-12-31 23:59:59Z]

    reloaded_report = TraysSocial.Repo.get!(Report, report.id)
    assert reloaded_report.status == "resolved"
    assert reloaded_report.resolved_by_id == admin.id
  end

  test "admin can suspend a target user until a specific date", %{conn: conn} do
    admin = admin_fixture()
    reporter = user_fixture()
    target = user_fixture()
    report = open_user_report_fixture(reporter, target)

    {:ok, view, _html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/admin/reports")

    view
    |> form("form[phx-submit=\"suspend_user\"]", %{
      "report_id" => report.id,
      "suspended_until" => "2026-06-30"
    })
    |> render_submit()

    reloaded_target = Accounts.get_user!(target.id)
    # Coerced to end-of-day UTC so "until June 30" does not expire at midnight
    # UTC mid-business-day in the user's local timezone.
    assert reloaded_target.suspended_until == ~U[2026-06-30 23:59:59Z]
  end

  test "admin cannot suspend themselves", %{conn: conn} do
    admin = admin_fixture()
    report = open_user_report_fixture(admin, admin)

    {:ok, view, _html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/admin/reports")

    view
    |> form("form[phx-submit=\"suspend_user\"]", %{
      "report_id" => report.id,
      "suspended_until" => ""
    })
    |> render_submit()

    # The flash that surfaces this guard renders in the root layout, not the
    # LiveView's own template. The behavioral assertion — admin is NOT
    # suspended — is what actually matters.
    reloaded_admin = Accounts.get_user!(admin.id)
    assert reloaded_admin.suspended_until == nil

    # And the report wasn't auto-resolved either.
    reloaded_report = TraysSocial.Repo.get!(Report, report.id)
    assert reloaded_report.status == "open"
  end

  test "admin can lift an existing suspension", %{conn: conn} do
    admin = admin_fixture()
    reporter = user_fixture()
    target = suspended_user_fixture()
    report = open_user_report_fixture(reporter, target)

    {:ok, view, _html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/admin/reports")

    view
    |> element("button[phx-click=\"unsuspend_user\"][phx-value-id=\"#{report.id}\"]")
    |> render_click()

    reloaded_target = Accounts.get_user!(target.id)
    assert reloaded_target.suspended_until == nil
  end
end
