defmodule TraysSocial.Notifications do
  import Ecto.Query, warn: false
  alias TraysSocial.Repo
  alias TraysSocial.Notifications.Notification

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
end
