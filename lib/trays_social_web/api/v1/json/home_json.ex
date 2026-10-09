defmodule TraysSocialWeb.API.V1.JSON.HomeJSON do
  @moduledoc """
  Renders `TraysSocial.Home.build/2` for `GET /api/v1/home`. Recipe rows reuse
  `PostJSON`, Tonight reuses `MealPlanJSON`, and user rows carry only the
  fields the Home avatars need.
  """

  alias TraysSocialWeb.API.V1.JSON.MealPlanJSON
  alias TraysSocialWeb.API.V1.JSON.PostJSON

  def render(home, opts) do
    %{
      jump_back_in: PostJSON.render_list(home.jump_back_in, opts),
      tonight: render_tonight(home.tonight),
      friends_trays: Enum.map(home.friends_trays, &render_friend/1),
      new_from_following: PostJSON.render_list(home.new_from_following, opts),
      suggested_cooks: Enum.map(home.suggested_cooks, &render_cook/1)
    }
  end

  defp render_tonight(nil), do: nil
  defp render_tonight(entry), do: MealPlanJSON.render_entry(entry)

  # last_posted_at is a :utc_datetime (or nil for a follow with no recipes),
  # so Jason encodes it as a Z-suffixed ISO 8601 string.
  defp render_friend(%{user: user, last_posted_at: last_posted_at}) do
    %{
      id: user.id,
      username: user.username,
      profile_photo_url: user.profile_photo_url,
      last_posted_at: last_posted_at
    }
  end

  defp render_cook(%{user: user, recipe_count: count}) do
    %{
      id: user.id,
      username: user.username,
      profile_photo_url: user.profile_photo_url,
      recipe_count: count
    }
  end
end
