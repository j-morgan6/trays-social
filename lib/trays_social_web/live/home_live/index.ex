defmodule TraysSocialWeb.HomeLive.Index do
  @moduledoc """
  The recipe-first Home page: welcome for new cooks, Jump back in, Tonight,
  Friends' trays, and a finite New from people you follow row.
  """
  use TraysSocialWeb, :live_view

  alias TraysSocial.Home

  on_mount {TraysSocialWeb.UserAuth, :require_authenticated_user}
  on_mount {TraysSocialWeb.UserAuth, :require_confirmed_user}
  on_mount {TraysSocialWeb.NotificationsHook, :mount_notifications}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Home")
      |> assign(:current_tab, :home)

    if connected?(socket) do
      # The web has no client time zone yet, so Home.build/2 falls back to
      # UTC "today" for Tonight. iOS sends its local date.
      {:ok, assign(socket, home: Home.build(socket.assigns.current_scope.user), loading: false)}
    else
      {:ok, assign(socket, home: nil, loading: true)}
    end
  end

  def post_title(post), do: TraysSocialWeb.ExploreLive.Index.post_title(post)

  def welcome?(home), do: home.jump_back_in == [] and home.friends_trays == []
end
