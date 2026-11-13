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
        body: "Default test body — useful feedback here.",
        subject: "Default subject"
      })

    {:ok, sub} = Feedback.submit(user, attrs)
    Feedback.get_submission!(sub.id)
  end

  # A table cell whose whole text is `text`, so a match cannot come from a
  # link href or another column.
  defp cell(text), do: ~r{<td[^>]*>\s*#{text}\s*</td>}

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

  test "the list shows kind and platform and filters by kind", %{conn: conn} do
    admin = admin_fixture()
    bug = submission_fixture(%{subject: "Save is broken", kind: "bug", platform: "web"})
    idea = submission_fixture(%{subject: "Love the app", kind: "feedback"})

    {:ok, view, html} = conn |> log_in_user(admin) |> live(~p"/admin/feedback")

    assert html =~ "<th>Kind</th>"
    assert html =~ "<th>Platform</th>"
    bug_row = view |> element("tr", "Save is broken") |> render()
    idea_row = view |> element("tr", "Love the app") |> render()
    assert bug_row =~ cell("bug")
    assert bug_row =~ cell("web")
    assert idea_row =~ cell("feedback")
    assert idea_row =~ cell("ios")

    html =
      view
      |> form("form", %{"kind" => "bug"})
      |> render_change()

    assert html =~ "/admin/feedback/#{bug.id}\""
    refute html =~ "/admin/feedback/#{idea.id}\""
  end

  test "the detail panel shows build, screen and user agent", %{conn: conn} do
    admin = admin_fixture()

    sub =
      submission_fixture(%{
        kind: "bug",
        app_version: "1.1.0",
        app_build: "372",
        os_version: "17.5",
        device_model: "iPhone15,3",
        screen: "RecipeEditorScreen",
        user_agent: "TraysSocial/1.1.0 (iPhone; iOS 17.5)"
      })

    {:ok, _view, html} =
      conn |> log_in_user(admin) |> live(~p"/admin/feedback/#{sub.id}")

    for label <- [
          "Kind",
          "Platform",
          "App version",
          "Build",
          "OS",
          "Device",
          "Screen",
          "User agent"
        ] do
      assert html =~ label
    end

    assert html =~ "372"
    assert html =~ "RecipeEditorScreen"
    assert html =~ "TraysSocial/1.1.0 (iPhone; iOS 17.5)"
    assert html =~ "iPhone15,3"
  end

  test "rows without the bug-report context render with fallbacks", %{conn: conn} do
    admin = admin_fixture()
    sub = submission_fixture(%{subject: "Old style row"})

    {:ok, _view, html} =
      conn |> log_in_user(admin) |> live(~p"/admin/feedback/#{sub.id}")

    assert html =~ "Old style row"

    for label <- ["Build", "Screen", "User agent"] do
      assert html =~ ~r{>#{label}</dt>\s*<dd[^>]*>—</dd>}
    end
  end

  test "an admin who loses is_admin is refused on the next event", %{conn: conn} do
    admin = admin_fixture()
    sub = submission_fixture(%{subject: "Do not resolve"})

    {:ok, view, _html} =
      conn |> log_in_user(admin) |> live(~p"/admin/feedback/#{sub.id}")

    {:ok, _} = Accounts.set_admin(admin, false)

    assert {:error, {:redirect, %{to: "/feed"}}} =
             view
             |> element(~s(button[phx-click="mark_resolved"][phx-value-id="#{sub.id}"]))
             |> render_click()

    assert Feedback.get_submission!(sub.id).status == "new"
  end

  test "show route renders the full body", %{conn: conn} do
    admin = admin_fixture()
    sub = submission_fixture(%{body: "Full body line 1\nFull body line 2"})

    {:ok, _view, html} =
      conn |> log_in_user(admin) |> live(~p"/admin/feedback/#{sub.id}")

    assert html =~ "Full body line 1"
    assert html =~ "Full body line 2"
  end

  test "show route escapes markup and control characters in the stored body", %{conn: conn} do
    admin = admin_fixture()
    sub = submission_fixture(%{body: "Before\n<script>alert(1)</script>\u0007\tAfter"})

    {:ok, _view, html} =
      conn |> log_in_user(admin) |> live(~p"/admin/feedback/#{sub.id}")

    refute html =~ "<script>alert(1)</script>"
    assert html =~ "&lt;script&gt;alert(1)&lt;/script&gt;"
    assert html =~ "Before"
    assert html =~ "After"
  end

  test "mark_triaged transitions status", %{conn: conn} do
    admin = admin_fixture()
    sub = submission_fixture(%{subject: "Triage me"})

    {:ok, view, _html} =
      conn |> log_in_user(admin) |> live(~p"/admin/feedback/#{sub.id}")

    view
    |> element(~s(button[phx-click="mark_triaged"][phx-value-id="#{sub.id}"]))
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
    |> element(~s(button[phx-click="mark_resolved"][phx-value-id="#{sub.id}"]))
    |> render_click()

    reloaded = Feedback.get_submission!(sub.id)
    assert reloaded.status == "resolved"
  end
end
