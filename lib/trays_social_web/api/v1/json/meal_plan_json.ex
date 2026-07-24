defmodule TraysSocialWeb.API.V1.JSON.MealPlanJSON do
  alias TraysSocial.Uploads.ImageProcessor

  def render_entries(entries) do
    Enum.map(entries, &render_entry/1)
  end

  def render_entry(entry) do
    %{
      id: entry.id,
      date: entry.date,
      post: render_post(entry.post)
    }
  end

  # D106: no rescue here — if the post_photos preload is absent this should
  # crash loudly in test rather than silently render a nil thumbnail.
  defp render_post(post) do
    thumb_url =
      case Enum.sort_by(post.post_photos, & &1.position) do
        [photo | _] -> ImageProcessor.thumb_url(photo.url)
        [] -> nil
      end

    %{
      id: post.id,
      caption: post.caption,
      thumbnail_url: thumb_url,
      cooking_time_minutes: post.cooking_time_minutes,
      type: post.type
    }
  end
end
