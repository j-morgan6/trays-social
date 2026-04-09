defmodule TraysSocialWeb.API.V1.JSON.NotificationJSON do
  alias TraysSocial.Uploads.ImageProcessor

  def render(notification) do
    %{
      id: notification.id,
      type: notification.type,
      read_at: notification.read_at,
      inserted_at: notification.inserted_at,
      actor: render_actor(notification.actor),
      post: render_post(notification.post)
    }
  end

  def render_list(notifications) do
    Enum.map(notifications, &render/1)
  end

  defp render_actor(nil), do: nil

  defp render_actor(actor) do
    %{
      id: actor.id,
      username: actor.username,
      profile_photo_url: actor.profile_photo_url
    }
  end

  defp render_post(nil), do: nil

  defp render_post(post) do
    thumb_url =
      case Map.get(post, :post_photos) do
        [photo | _] when not is_nil(photo) -> ImageProcessor.thumb_url(photo.photo_url)
        _ -> nil
      end

    %{
      id: post.id,
      thumbnail_url: thumb_url
    }
  rescue
    _ -> %{id: post.id, thumbnail_url: nil}
  end
end
