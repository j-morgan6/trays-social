defmodule TraysSocialWeb.Admin.IosCrashesLiveTest do
  use TraysSocialWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.Diagnostics

  defp admin_fixture do
    user = user_fixture()
    {:ok, admin} = Accounts.set_admin(user, true)
    admin
  end

  defp payload_fixture(overrides) do
    attrs =
      Map.merge(
        %{
          payload_type: "diagnostic",
          payload: %{"crashDiagnostics" => [%{"signal" => "SIGSEGV"}]},
          received_at: DateTime.utc_now() |> DateTime.truncate(:second),
          app_version: "1.0.0",
          os_version: "17.5",
          device_model: "iPhone15,3"
        },
        overrides
      )

    {:ok, record} = Diagnostics.store_payload(attrs)
    record
  end

  test "non-admin gets a 404 from the router pipeline", %{conn: conn} do
    user = user_fixture()
    conn = conn |> log_in_user(user) |> get(~p"/admin/ios-crashes")
    assert conn.status == 404
  end

  test "admin lists payloads newest first", %{conn: conn} do
    admin = admin_fixture()
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    older = payload_fixture(%{received_at: DateTime.add(now, -3600, :second)})
    newer = payload_fixture(%{received_at: now})

    {:ok, _view, html} =
      conn |> log_in_user(admin) |> live(~p"/admin/ios-crashes")

    assert html =~ "iOS crashes"
    # Compare the position of the per-row Open links — that's the only
    # place each payload's id is uniquely rendered, so this is robust to
    # filter-dropdown ordering.
    newer_pos = :binary.match(html, "/admin/ios-crashes/#{newer.id}\"") |> elem(0)
    older_pos = :binary.match(html, "/admin/ios-crashes/#{older.id}\"") |> elem(0)
    assert newer_pos < older_pos
  end

  test "filter narrows by payload_type", %{conn: conn} do
    admin = admin_fixture()
    diag = payload_fixture(%{payload_type: "diagnostic"})
    metric = payload_fixture(%{payload_type: "metric"})

    {:ok, view, _html} =
      conn |> log_in_user(admin) |> live(~p"/admin/ios-crashes")

    html =
      view
      |> form("form", %{"payload_type" => "metric"})
      |> render_change()

    assert html =~ "/admin/ios-crashes/#{metric.id}\""
    refute html =~ "/admin/ios-crashes/#{diag.id}\""
  end

  test "show route renders the pretty-printed payload", %{conn: conn} do
    admin = admin_fixture()
    payload = payload_fixture(%{payload: %{"crashDiagnostics" => [%{"signal" => "SIGABRT"}]}})

    {:ok, _view, html} =
      conn |> log_in_user(admin) |> live(~p"/admin/ios-crashes/#{payload.id}")

    assert html =~ "Payload ##{payload.id}"
    assert html =~ "SIGABRT"
  end
end
