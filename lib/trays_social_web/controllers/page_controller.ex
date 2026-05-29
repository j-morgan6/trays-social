defmodule TraysSocialWeb.PageController do
  use TraysSocialWeb, :controller

  # Public marketing landing page (W120). Authenticated visitors are sent
  # straight to their feed so the root URL behaves like the app home for
  # logged-in users while remaining a public landing page for everyone else.
  # current_scope is populated (nil-or-struct) by :fetch_current_scope_for_user
  # in the :browser pipeline.
  def home(conn, _params) do
    case conn.assigns[:current_scope] do
      %{user: %{}} ->
        redirect(conn, to: ~p"/feed")

      _ ->
        render(conn, :home)
    end
  end
end
