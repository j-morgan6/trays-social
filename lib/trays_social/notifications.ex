defmodule TraysSocial.Notifications do
  import Ecto.Query, warn: false
  alias TraysSocial.Notifications.Notification
  alias TraysSocial.Notifications.PushSender
  alias TraysSocial.Repo

  @doc """
  Creates a notification and broadcasts it to the recipient via PubSub.
  No-op if user_id == actor_id (no self-notifications).
  """
  def create_notification(attrs) do
    user_id = Map.get(attrs, :user_id)
    actor_id = Map.get(attrs, :actor_id)

    if user_id && actor_id && user_id != actor_id do
      case %Notification{} |> Notification.changeset(attrs) |> Repo.insert() do
        {:ok, notification} ->
          notification = Repo.preload(notification, [:actor, :post])

          Phoenix.PubSub.broadcast(
            TraysSocial.PubSub,
            "notifications:#{user_id}",
            {:new_notification, notification}
          )

          # Send push notification
          push_title = push_title_for(notification)
          push_body = push_body_for(notification)
          PushSender.send_push(user_id, push_title, push_body, %{type: notification.type})

          {:ok, notification}

        error ->
          error
      end
    else
      {:ok, :skipped}
    end
  end

  @doc """
  Returns notifications for a user, newest first, with actor and post preloaded.
  """
  def list_notifications(user_id) do
    Notification
    |> where([n], n.user_id == ^user_id)
    |> order_by([n], desc: n.inserted_at)
    |> limit(50)
    |> preload([:actor, :post])
    |> Repo.all()
  end

  @doc """
  Returns cursor-paginated notifications for a user, newest first, with actor and post preloaded.

  ## Options

    * `:limit` — page size (default 20)
    * `:cursor_id`, `:cursor_time` — cursor pair for pagination
    * `:blocked_user_ids` — list of user ids whose notifications should be
      excluded. Mirrors the D65 pattern shipped on comment/feed queries.
      Notifications with a nil `actor_id` (system notifications, future
      automated events) pass through unfiltered — the block list only
      hides notifications triggered by another *user* the viewer has
      blocked.
  """
  def list_notifications_paginated(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    cursor_id = Keyword.get(opts, :cursor_id)
    cursor_time = Keyword.get(opts, :cursor_time)
    blocked_user_ids = Keyword.get(opts, :blocked_user_ids, [])

    query =
      Notification
      |> where([n], n.user_id == ^user_id)
      |> exclude_blocked_actors(blocked_user_ids)
      |> order_by([n], desc: n.inserted_at, desc: n.id)
      |> limit(^limit)
      |> preload([:actor, :post])

    query =
      if cursor_id && cursor_time do
        where(
          query,
          [n],
          n.inserted_at < ^cursor_time or (n.inserted_at == ^cursor_time and n.id < ^cursor_id)
        )
      else
        query
      end

    Repo.all(query)
  end

  # SQL note: `actor_id not in (...)` evaluates to NULL (filtered out) when
  # actor_id IS NULL, which would silently drop legitimate system
  # notifications. The explicit `is_nil` guard keeps them visible.
  defp exclude_blocked_actors(query, []), do: query

  defp exclude_blocked_actors(query, blocked_ids) do
    where(query, [n], is_nil(n.actor_id) or n.actor_id not in ^blocked_ids)
  end

  @doc """
  Marks specific notifications as read by their IDs. Only marks notifications belonging to the user.
  """
  def mark_read(user_id, notification_ids) when is_list(notification_ids) do
    now = DateTime.utc_now(:second)

    {count, _} =
      Notification
      |> where([n], n.user_id == ^user_id and n.id in ^notification_ids and is_nil(n.read_at))
      |> Repo.update_all(set: [read_at: now])

    {:ok, count}
  end

  @doc """
  Marks all unread notifications as read for a user. Broadcasts the read event.
  """
  def mark_all_read(user_id) do
    now = DateTime.utc_now(:second)

    {count, _} =
      Notification
      |> where([n], n.user_id == ^user_id and is_nil(n.read_at))
      |> Repo.update_all(set: [read_at: now])

    if count > 0 do
      Phoenix.PubSub.broadcast(
        TraysSocial.PubSub,
        "notifications:#{user_id}",
        {:notifications_read, user_id}
      )
    end

    :ok
  end

  @doc """
  Returns the count of unread notifications for a user.
  """
  def unread_count(user_id) do
    Notification
    |> where([n], n.user_id == ^user_id and is_nil(n.read_at))
    |> Repo.aggregate(:count)
  end

  ## Push notification content

  defp push_title_for(%{type: "like"}), do: "New Like"
  defp push_title_for(%{type: "comment"}), do: "New Comment"
  defp push_title_for(%{type: "follow"}), do: "New Follower"
  defp push_title_for(_), do: "Trays"

  defp push_body_for(%{actor: %{username: username}, type: "like"}), do: "#{username} liked your post"
  defp push_body_for(%{actor: %{username: username}, type: "comment"}), do: "#{username} commented on your post"
  defp push_body_for(%{actor: %{username: username}, type: "follow"}), do: "#{username} started following you"
  defp push_body_for(_), do: "You have a new notification"

  ## Device Tokens

  alias TraysSocial.Notifications.DeviceToken

  @doc """
  Registers a device token for push notifications.

  Upserts on (user_id, token) — same-user repeat registration just refreshes
  `updated_at`. If the token already exists bound to a DIFFERENT user_id,
  returns `{:error, :token_owned_by_other_user}` rather than silently
  rebinding (D43): the previous behavior let any authenticated user hijack
  push delivery for any token they happened to learn (logs, debug builds,
  shared device). APNS tokens aren't user-secret, only unguessable.
  """
  def register_device(user_id, token, platform \\ "ios") do
    case Repo.get_by(DeviceToken, token: token) do
      %DeviceToken{user_id: existing_user_id} when existing_user_id != user_id ->
        {:error, :token_owned_by_other_user}

      _ ->
        %DeviceToken{}
        |> DeviceToken.changeset(%{user_id: user_id, token: token, platform: platform})
        |> Repo.insert(
          on_conflict: [set: [user_id: user_id, updated_at: DateTime.utc_now(:second)]],
          # Conflict target stays at :token. The pre-check above closes the
          # cross-user hijack window; under concurrent inserts the unique
          # constraint races to the same outcome because both rows would
          # set the same user_id (the caller's) and only one wins.
          conflict_target: :token
        )
    end
  end

  @doc """
  Unregisters a device token scoped to the caller (D43).

  Returns `:ok` when a matching (user_id, token) row was deleted,
  `{:error, :not_found}` otherwise. The "no matching row" outcome is
  identical for missing-token and cross-user-token requests — callers
  must surface the same 404 for both to avoid an IDOR enumeration
  oracle (a user pinging tokens and getting different responses for
  "yours" vs. "someone else's" leaks ownership).
  """
  def unregister_device(user_id, token) do
    query = from d in DeviceToken, where: d.user_id == ^user_id and d.token == ^token

    case Repo.delete_all(query) do
      {0, _} -> {:error, :not_found}
      {_, _} -> :ok
    end
  end

  @doc """
  Returns all device tokens for a user.
  """
  def list_device_tokens(user_id) do
    DeviceToken
    |> where([d], d.user_id == ^user_id)
    |> Repo.all()
  end

  @doc """
  Removes a specific device token by its token string.
  Used for cleaning up invalid APNs tokens.
  """
  def delete_device_token(token) do
    DeviceToken
    |> where([d], d.token == ^token)
    |> Repo.delete_all()

    :ok
  end
end
