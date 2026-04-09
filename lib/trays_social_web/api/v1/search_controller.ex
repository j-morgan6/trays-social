defmodule TraysSocialWeb.API.V1.SearchController do
  use TraysSocialWeb, :controller

  alias TraysSocial.Posts
  alias TraysSocial.Accounts
  alias TraysSocialWeb.API.V1.JSON.PostJSON

  def index(conn, params) do
    user = conn.assigns.current_user
    query = params["q"] || ""
    max_cooking_time = parse_int(params["max_cooking_time"])
    tag = params["tag"]

    posts =
      Posts.search_posts(query,
        limit: 20,
        max_cooking_time: max_cooking_time,
        tag: tag
      )

    users =
      if tag || max_cooking_time do
        []
      else
        Accounts.search_users(query, limit: 10)
      end

    post_ids = Enum.map(posts, & &1.id)
    liked_post_ids = Posts.liked_post_ids_for_user(user.id, post_ids)
    bookmarked_post_ids = Posts.bookmarked_post_ids_for_user(user.id, post_ids)

    json(conn, %{
      data: %{
        posts: PostJSON.render_list(posts, %{liked_post_ids: liked_post_ids, bookmarked_post_ids: bookmarked_post_ids}),
        users: Enum.map(users, &render_user/1)
      }
    })
  end

  defp render_user(user) do
    %{
      id: user.id,
      username: user.username,
      bio: user.bio,
      profile_photo_url: user.profile_photo_url
    }
  end

  defp parse_int(nil), do: nil

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_int(val) when is_integer(val), do: val
end
