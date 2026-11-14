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
  import TraysSocial.PostsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.Posts.Post
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
      ~s(button[phx-click="resolve"][phx-value-id="#{report.id}"][phx-value-status="resolved"])
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
    |> element(~s(button[phx-click="unsuspend_user"][phx-value-id="#{report.id}"]))
    |> render_click()

    reloaded_target = Accounts.get_user!(target.id)
    assert reloaded_target.suspended_until == nil
  end

  describe "per-event admin re-check (W264)" do
    defp resolve_button(report),
      do:
        ~s(button[phx-click="resolve"][phx-value-id="#{report.id}"][phx-value-status="resolved"])

    defp report_status(report), do: TraysSocial.Repo.get!(Report, report.id).status

    test "an admin who loses is_admin is refused on the next event", %{conn: conn} do
      admin = admin_fixture()
      report = open_report_fixture(user_fixture())

      {:ok, view, _html} = conn |> log_in_user(admin) |> live(~p"/admin/reports")

      # The demotion is written by this test process while the LiveView
      # process stays alive; the hook must read it from the database.
      {:ok, _} = Accounts.set_admin(admin, false)

      assert {:error, {:redirect, %{to: "/feed"}}} =
               view |> element(resolve_button(report)) |> render_click()

      assert report_status(report) == "open"
    end

    test "an admin who loses is_admin cannot suspend a user", %{conn: conn} do
      admin = admin_fixture()
      target = user_fixture()
      report = open_user_report_fixture(user_fixture(), target)

      {:ok, view, _html} = conn |> log_in_user(admin) |> live(~p"/admin/reports")

      {:ok, _} = Accounts.set_admin(admin, false)

      assert {:error, {:redirect, %{to: "/feed"}}} =
               view
               |> form("form[phx-submit=\"suspend_user\"]", %{
                 "report_id" => report.id,
                 "suspended_until" => ""
               })
               |> render_submit()

      assert Accounts.get_user!(target.id).suspended_until == nil
      assert report_status(report) == "open"
    end

    test "an admin who loses is_admin cannot remove a post or lift a suspension",
         %{conn: conn} do
      admin = admin_fixture()
      reporter = user_fixture()
      post = post_fixture(%{user_id: user_fixture().id})

      {:ok, post_report} =
        Reports.create_report(reporter, %{target_type: "post", target_id: post.id, reason: "spam"})

      suspended = suspended_user_fixture()
      user_report = open_user_report_fixture(reporter, suspended)

      conn = log_in_user(conn, admin)
      {:ok, remove_view, _html} = live(conn, ~p"/admin/reports")
      {:ok, unsuspend_view, _html} = live(conn, ~p"/admin/reports")

      {:ok, _} = Accounts.set_admin(admin, false)

      assert {:error, {:redirect, %{to: "/feed"}}} =
               remove_view
               |> element(~s(button[phx-click="remove_post"][phx-value-id="#{post_report.id}"]))
               |> render_click()

      assert {:error, {:redirect, %{to: "/feed"}}} =
               unsuspend_view
               |> element(
                 ~s(button[phx-click="unsuspend_user"][phx-value-id="#{user_report.id}"])
               )
               |> render_click()

      # Repo.get! rather than Posts.get_post!, which filters removed posts.
      assert TraysSocial.Repo.get!(Post, post.id).removed_at == nil
      assert report_status(post_report) == "open"
      assert Accounts.get_user!(suspended.id).suspended_until != nil
      assert report_status(user_report) == "open"
    end

    test "an admin demoted and re-promoted before the click can still resolve", %{conn: conn} do
      admin = admin_fixture()
      report = open_report_fixture(user_fixture())

      {:ok, view, _html} = conn |> log_in_user(admin) |> live(~p"/admin/reports")

      # Re-promote from the demoted struct: set_admin(admin, true) on the
      # original struct is a no-op changeset (is_admin already true there).
      {:ok, demoted} = Accounts.set_admin(admin, false)
      {:ok, _} = Accounts.set_admin(demoted, true)

      view |> element(resolve_button(report)) |> render_click()

      reloaded = TraysSocial.Repo.get!(Report, report.id)
      assert reloaded.status == "resolved"
      assert reloaded.resolved_by_id == admin.id
    end

    test "an admin whose account is deleted is refused on the next event", %{conn: conn} do
      admin = admin_fixture()
      report = open_report_fixture(user_fixture())

      {:ok, view, _html} = conn |> log_in_user(admin) |> live(~p"/admin/reports")

      {:ok, _} = Accounts.delete_account(admin)
      assert Accounts.get_user(admin.id) == nil

      assert {:error, {:redirect, %{to: "/feed"}}} =
               view |> element(resolve_button(report)) |> render_click()

      assert report_status(report) == "open"
    end
  end
end
