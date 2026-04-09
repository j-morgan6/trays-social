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
  Upserts — if the token already exists, updates the user_id.
  """
  def register_device(user_id, token, platform \\ "ios") do
    %DeviceToken{}
    |> DeviceToken.changeset(%{user_id: user_id, token: token, platform: platform})
    |> Repo.insert(
      on_conflict: [set: [user_id: user_id, updated_at: DateTime.utc_now(:second)]],
      conflict_target: :token
    )
  end

  @doc """
  Unregisters a device token.
  """
  def unregister_device(token) do
    case Repo.get_by(DeviceToken, token: token) do
      nil -> :ok
      device_token -> Repo.delete(device_token)
    end

    :ok
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
