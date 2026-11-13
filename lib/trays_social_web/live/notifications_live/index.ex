defmodule TraysSocialWeb.NotificationsLive.Index do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Notifications

  on_mount {TraysSocialWeb.UserAuth, :require_authenticated_user}
  on_mount {TraysSocialWeb.UserAuth, :require_confirmed_user}
  on_mount {TraysSocialWeb.NotificationsHook, :mount_notifications}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    # W168: same blocked-actor exclusion as the API list and the shared
    # unread badge, so the web list can always reconcile with the count.
    notifications =
      Notifications.list_notifications(user.id,
        blocked_user_ids: TraysSocial.Accounts.blocked_user_ids(user.id)
      )

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

  # A notification whose actor is gone still renders (the blocked-actor
  # filter lets nil actors through), so every actor read is nil-safe.
  def actor_name(%{actor: %{username: username}}), do: username
  def actor_name(_notification), do: "Someone"

  def actor_photo(%{actor: %{profile_photo_url: url}}), do: url
  def actor_photo(_notification), do: nil

  def actor_bio(%{type: "follow", actor: %{bio: bio}}), do: bio
  def actor_bio(_notification), do: nil

  def target_path(%{type: "follow", actor: %{username: username}}), do: ~p"/@#{username}"
  def target_path(%{post: %{id: id}}), do: ~p"/posts/#{id}"
  def target_path(_notification), do: ~p"/feed"

  # A recipe title from a post's caption, by the shared rule
  # (TrayFormatting.post_title/1, D126). No post gives nil, so the template
  # can say "recipe" instead.
  def post_title(nil), do: nil
  def post_title(post), do: TraysSocialWeb.TrayFormatting.post_title(post)
end
