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
  """

  use TraysSocialWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller, only: [put_view: 2, render: 2]

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
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    end
  end

  defp admin?(%{current_scope: %{user: %{is_admin: true}}}), do: true
  defp admin?(_), do: false
end
