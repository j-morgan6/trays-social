defmodule TraysSocialWeb.API.V1.JSON.PostJSON do
  @moduledoc """
  JSON rendering for posts in API v1.
  """

  alias TraysSocial.Uploads.ImageProcessor

  def render(post, opts \\ %{}) do
    liked_post_ids = Map.get(opts, :liked_post_ids, MapSet.new())
    bookmarked_post_ids = Map.get(opts, :bookmarked_post_ids, MapSet.new())

    %{
      id: post.id,
      type: post.type,
      caption: post.caption,
      cooking_time_minutes: post.cooking_time_minutes,
      servings: post.servings,
      like_count: post.like_count,
      comment_count: post.comment_count,
      liked_by_current_user: MapSet.member?(liked_post_ids, post.id),
      bookmarked_by_current_user: MapSet.member?(bookmarked_post_ids, post.id),
      inserted_at: post.inserted_at,
      user: render_user(post.user),
      photos: render_photos(post),
      ingredients: render_ingredients(post),
      cooking_steps: render_cooking_steps(post),
      tools: render_tools(post),
      tags: render_tags(post)
    }
  end

  def render_list(posts, opts \\ %{}) do
    Enum.map(posts, &render(&1, opts))
  end

  defp render_user(%{} = user) do
    %{
      id: user.id,
      username: user.username,
      profile_photo_url: user.profile_photo_url
    }
  end

  defp render_user(_), do: nil

  defp render_photos(post) do
    photos = Map.get(post, :post_photos) || []

    Enum.map(photos, fn photo ->
      %{
        url: photo.url,
        thumb_url: ImageProcessor.thumb_url(photo.url),
        medium_url: ImageProcessor.medium_url(photo.url),
        position: photo.position
      }
    end)
  end

  defp render_ingredients(post) do
    ingredients = Map.get(post, :ingredients) || []
    Enum.map(ingredients, fn i -> %{name: i.name, quantity: i.quantity, unit: i.unit} end)
  end

  defp render_cooking_steps(post) do
    steps = Map.get(post, :cooking_steps) || []

    steps
    |> Enum.sort_by(& &1.order)
    |> Enum.map(fn s -> %{position: s.order, instruction: s.description} end)
  end

  defp render_tools(post) do
    tools = Map.get(post, :tools) || []
    Enum.map(tools, fn t -> %{name: t.name} end)
  end

  defp render_tags(post) do
    tags = Map.get(post, :post_tags) || []
    Enum.map(tags, fn t -> t.tag end)
  end
end
