defmodule TraysSocialWeb.NotificationsHook do
  import Phoenix.Component
  import Phoenix.LiveView

  alias TraysSocial.Notifications

  def on_mount(:mount_notifications, _params, _session, socket) do
    socket =
      case socket.assigns[:current_scope] do
        %{user: user} ->
          if connected?(socket) do
            Phoenix.PubSub.subscribe(TraysSocial.PubSub, "notifications:#{user.id}")
          end

          unread = if connected?(socket), do: Notifications.unread_count(user.id), else: 0

          socket
          |> assign(:unread_notifications, unread)
          |> attach_hook(:notifications_badge, :handle_info, fn
            {:new_notification, _notification}, sock ->
              {:halt, update(sock, :unread_notifications, &(&1 + 1))}

            {:notifications_read, _user_id}, sock ->
              {:halt, assign(sock, :unread_notifications, 0)}

            _other, sock ->
              {:cont, sock}
          end)

        _ ->
          assign(socket, :unread_notifications, 0)
      end

    {:cont, socket}
  end
end
