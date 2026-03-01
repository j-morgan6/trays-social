defmodule TraysSocialWeb.NotificationsLive.Index do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Notifications

  on_mount {TraysSocialWeb.UserAuth, :require_authenticated_user}
  on_mount {TraysSocialWeb.NotificationsHook, :mount_notifications}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    notifications = Notifications.list_notifications(user.id)

    if connected?(socket) do
      Notifications.mark_all_read(user.id)
    end

    socket =
      socket
      |> assign(:page_title, "Notifications")
      |> assign(:current_tab, :notifications)
      |> stream(:notifications, notifications)

    {:ok, socket}
  end

  @impl true
  def handle_info({:new_notification, notification}, socket) do
    {:noreply, stream_insert(socket, :notifications, notification, at: 0)}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}
end
