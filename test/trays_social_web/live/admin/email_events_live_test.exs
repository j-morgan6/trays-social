defmodule TraysSocialWeb.Admin.EmailEventsLiveTest do
  @moduledoc """
  W264: EmailEventsLive shows recipient email addresses, so it carries the
  same three on_mount hooks as FeedbackLive rather than relying on the
  /admin router pipeline, which runs only on HTTP requests.
  """
  use TraysSocialWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.Email
  alias TraysSocialWeb.Admin.EmailEventsLive

  @recipient "recipient@example.com"

  defp admin_fixture do
    user = user_fixture()
    {:ok, admin} = Accounts.set_admin(user, true)
    admin
  end

  defp event_fixture(overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          event_id: "ev_#{System.unique_integer([:positive])}",
          email_id: "em_#{System.unique_integer([:positive])}",
          event_type: "email.delivered",
          recipient: @recipient,
          payload: %{}
        },
        overrides
      )

    {:ok, event} = Email.upsert_event(attrs)
    event
  end

  test "mounts the auth, admin and per-event admin hooks in that order" do
    ids = Enum.map(EmailEventsLive.__live__()[:lifecycle].mount, & &1.id)

    assert ids == [
             {TraysSocialWeb.UserAuth, :require_authenticated_user},
             {TraysSocialWeb.Plugs.RequireAdmin, :ensure_admin},
             {TraysSocialWeb.Plugs.RequireAdmin, :ensure_admin_each_event}
           ]
  end

  test "an admin sees recent email events", %{conn: conn} do
    admin = admin_fixture()
    event = event_fixture(%{email_id: "em_visible"})

    {:ok, _view, html} = conn |> log_in_user(admin) |> live(~p"/admin/email-events")

    assert html =~ "Email events"
    assert html =~ event.email_id
    assert html =~ @recipient
  end

  test "a non-admin is refused at mount", %{conn: conn} do
    event_fixture()
    user = user_fixture()
    conn = log_in_user(conn, user)

    # HTTP request: the router pipeline answers 404 before the LiveView.
    http_conn = get(conn, ~p"/admin/email-events")
    assert http_conn.status == 404
    refute http_conn.resp_body =~ @recipient

    # Socket mount without the router (as on a live navigation): only the
    # module's own on_mount hooks stand in the way, and they redirect.
    session = %{"user_token" => Accounts.generate_user_session_token(user)}

    assert {:error, {:redirect, %{to: "/feed"}}} =
             live_isolated(conn, EmailEventsLive, session: session)
  end

  test "an admin who loses is_admin is refused on the next filter event", %{conn: conn} do
    admin = admin_fixture()
    event_fixture(%{event_type: "email.bounced"})

    {:ok, view, _html} = conn |> log_in_user(admin) |> live(~p"/admin/email-events")

    {:ok, _} = Accounts.set_admin(admin, false)

    assert {:error, {:redirect, %{to: "/feed"}}} =
             view
             |> form("form", %{"event_type" => "email.bounced"})
             |> render_change()
  end
end
