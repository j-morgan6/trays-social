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
      |> assign(:total_count, length(notifications))
      |> assign(:unread_count, Enum.count(notifications, &is_nil(&1.read_at)))
      |> stream(:notifications, notifications)

    {:ok, socket}
  end

  @impl true
  def handle_info({:new_notification, notification}, socket) do
    {:noreply,
     socket
     |> stream_insert(:notifications, notification, at: 0)
     |> update(:total_count, &(&1 + 1))
     |> update(:unread_count, fn n -> if is_nil(notification.read_at), do: n + 1, else: n end)}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  # Compact relative time for the notifications feed: "12m", "3 hr",
  # "Yesterday", "2d", or a calendar date once we're past a week. The
  # design uses this format in the mono row beneath each phrase.
  def relative_time(%DateTime{} = then), do: relative_time_from(then, DateTime.utc_now())

  def relative_time(%NaiveDateTime{} = then) do
    then |> DateTime.from_naive!("Etc/UTC") |> relative_time_from(DateTime.utc_now())
  end

  defp relative_time_from(then, now) do
    seconds = DateTime.diff(now, then, :second)
    minutes = div(seconds, 60)
    hours = div(minutes, 60)
    days = div(hours, 24)

    cond do
      seconds < 60 -> "Just now"
      minutes < 60 -> "#{minutes}m"
      hours < 24 -> "#{hours} hr"
      days == 1 -> "Yesterday"
      days < 7 -> "#{days}d"
      true -> Calendar.strftime(then, "%b %-d")
    end
  end

  # Derive a serif-friendly recipe title from a post's caption — the
  # caption is free-form text, so we take the first sentence/line and
  # fall back to a placeholder when it's empty.
  def post_title(nil), do: nil

  def post_title(%{caption: caption}) do
    case String.split(caption || "", ~r/[\n.!?]/, parts: 2, trim: true) do
      [t | _] ->
        case String.trim(t) do
          "" -> "Untitled recipe"
          title -> title
        end

      _ ->
        "Untitled recipe"
    end
  end
end
