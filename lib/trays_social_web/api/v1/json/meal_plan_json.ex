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

  @doc """
  Renders the derived grocery checklist returned by
  `TraysSocial.MealPlans.grocery_list/2`.

  The context returns the raw domain shape (`post.photo_url` = the stored
  original); thumbnailing and the `thumbnail_url` key name live here so the
  grocery list and the week view agree on one contract.
  """
  def render_grocery_list(groups) do
    Enum.map(groups, &render_grocery_group/1)
  end

  defp render_grocery_group(%{post: post, items: items}) do
    %{
      post: %{
        id: post.id,
        caption: post.caption,
        thumbnail_url: ImageProcessor.thumb_url(post.photo_url)
      },
      items: items
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
