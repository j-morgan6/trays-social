defmodule TraysSocialWeb.Plugs.RequireAdmin do
  @moduledoc """
  Plug + LiveView on_mount hook that gates a route to admins only.

  Requires `:require_authenticated_user` to have already run (current_scope
  must be set). Non-admin users get a 404 — not 403, not a redirect — so
  the existence of admin routes is not leaked to non-admins.

  ## Plug usage

      pipeline :require_admin do
        plug TraysSocialWeb.Plugs.RequireAdmin
      end

      scope "/admin", TraysSocialWeb.Admin do
        pipe_through [:browser, :require_authenticated_user, :require_admin]
        live "/reports", ReportsLive, :index
      end

  ## LiveView usage

      defmodule MyAdminLive do
        use TraysSocialWeb, :live_view
        on_mount {TraysSocialWeb.Plugs.RequireAdmin, :ensure_admin}
      end

  `:ensure_admin` checks once, at mount. A LiveView whose events change
  data or reveal sensitive data also mounts `:ensure_admin_each_event`
  (W261): it reloads the user before every `handle_event` and every
  live-patch `handle_params` and redirects to `/feed` when they are no
  longer an admin, so revoking `is_admin` takes effect on the next click
  or patch rather than the next page load. It costs one primary-key
  lookup per event or patch. FeedbackLive, ReportsLive, IosCrashesLive
  and EmailEventsLive (W264) mount it; a new admin LiveView should mount
  it too.

      on_mount {TraysSocialWeb.Plugs.RequireAdmin, :ensure_admin}
      on_mount {TraysSocialWeb.Plugs.RequireAdmin, :ensure_admin_each_event}
  """

  use TraysSocialWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller, only: [put_view: 2, render: 2]

  alias TraysSocial.Accounts
  alias TraysSocialWeb.ErrorHTML

  def init(opts), do: opts

  def call(conn, _opts) do
    if admin?(conn.assigns) do
      conn
    else
      conn
      |> put_status(:not_found)
      |> put_view(ErrorHTML)
      |> render("404.html")
      |> halt()
    end
  end

  def on_mount(:ensure_admin, _params, _session, socket) do
    if admin?(socket.assigns) do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/feed")}
    end
  end

  def on_mount(:ensure_admin_each_event, _params, _session, socket) do
    {:cont,
     socket
     |> Phoenix.LiveView.attach_hook(:admin_recheck, :handle_event, &recheck_admin/3)
     |> Phoenix.LiveView.attach_hook(:admin_recheck_params, :handle_params, &recheck_admin/3)}
  end

  # Shared by the :handle_event (event, params, socket) and :handle_params
  # (params, uri, socket) hooks; only the socket matters.
  defp recheck_admin(_first, _second, socket) do
    if still_admin?(socket.assigns) do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/feed")}
    end
  end

  defp still_admin?(%{current_scope: %{user: %{id: id}}}) when not is_nil(id) do
    match?(%{is_admin: true}, Accounts.get_user(id))
  end

  defp still_admin?(_), do: false

  defp admin?(%{current_scope: %{user: %{is_admin: true}}}), do: true
  defp admin?(_), do: false
end
