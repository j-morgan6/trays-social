defmodule TraysSocialWeb.Admin.FeedbackLiveTest do
  use TraysSocialWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.Feedback

  defp admin_fixture do
    user = user_fixture()
    {:ok, admin} = Accounts.set_admin(user, true)
    admin
  end

  defp submission_fixture(overrides) do
    {user, attrs} = Map.pop_lazy(overrides, :user, &user_fixture/0)

    attrs =
      Enum.into(attrs, %{
        user_id: user.id,
        body: "Default test body — useful feedback here.",
        subject: "Default subject"
      })

    {:ok, sub} = Feedback.submit(attrs)
    Feedback.get_submission!(sub.id)
  end

  test "non-admin gets 404 from the router pipeline", %{conn: conn} do
    user = user_fixture()
    conn = conn |> log_in_user(user) |> get(~p"/admin/feedback")
    assert conn.status == 404
  end

  test "admin lists submissions", %{conn: conn} do
    admin = admin_fixture()
    sub = submission_fixture(%{subject: "Crash on save"})

    {:ok, _view, html} = conn |> log_in_user(admin) |> live(~p"/admin/feedback")

    assert html =~ "Feedback"
    assert html =~ "Crash on save"
    assert html =~ "@#{sub.user.username}"
  end

  test "status filter narrows the list", %{conn: conn} do
    admin = admin_fixture()
    new_sub = submission_fixture(%{subject: "Stays new"})
    triaged_sub = submission_fixture(%{subject: "Already triaged"})
    {:ok, _} = Feedback.mark_triaged(triaged_sub)

    {:ok, view, _html} = conn |> log_in_user(admin) |> live(~p"/admin/feedback")

    html =
      view
      |> form("form", %{"status" => "triaged"})
      |> render_change()

    assert html =~ "/admin/feedback/#{triaged_sub.id}\""
    refute html =~ "/admin/feedback/#{new_sub.id}\""
  end

  test "show route renders the full body", %{conn: conn} do
    admin = admin_fixture()
    sub = submission_fixture(%{body: "Full body line 1\nFull body line 2"})

    {:ok, _view, html} =
      conn |> log_in_user(admin) |> live(~p"/admin/feedback/#{sub.id}")

    assert html =~ "Full body line 1"
    assert html =~ "Full body line 2"
  end

  test "mark_triaged transitions status", %{conn: conn} do
    admin = admin_fixture()
    sub = submission_fixture(%{subject: "Triage me"})

    {:ok, view, _html} =
      conn |> log_in_user(admin) |> live(~p"/admin/feedback/#{sub.id}")

    view
    |> element("button[phx-click=\"mark_triaged\"][phx-value-id=\"#{sub.id}\"]")
    |> render_click()

    reloaded = Feedback.get_submission!(sub.id)
    assert reloaded.status == "triaged"
  end

  test "mark_resolved transitions status", %{conn: conn} do
    admin = admin_fixture()
    sub = submission_fixture(%{subject: "Resolve me"})

    {:ok, view, _html} =
      conn |> log_in_user(admin) |> live(~p"/admin/feedback/#{sub.id}")

    view
    |> element("button[phx-click=\"mark_resolved\"][phx-value-id=\"#{sub.id}\"]")
    |> render_click()

    reloaded = Feedback.get_submission!(sub.id)
    assert reloaded.status == "resolved"
  end
end
