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

  # D106: no rescue here — a blanket rescue previously masked both a wrong
  # field name (photo_url vs url) and a missing post_photos preload for
  # weeks. If the preload is absent this should crash loudly in test.
  defp render_post(post) do
    thumb_url =
      case Enum.sort_by(post.post_photos, & &1.position) do
        [photo | _] -> ImageProcessor.thumb_url(photo.url)
        [] -> nil
      end

    %{
      id: post.id,
      thumbnail_url: thumb_url
    }
  end
end
