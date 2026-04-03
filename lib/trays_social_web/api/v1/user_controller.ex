defmodule TraysSocialWeb.API.V1.UserController do
  use TraysSocialWeb, :controller

  action_fallback TraysSocialWeb.API.V1.FallbackController

  alias TraysSocial.Accounts
  alias TraysSocial.Posts
  alias TraysSocialWeb.API.V1.JSON.PostJSON

  @page_size 20

  def show(conn, %{"username" => username}) do
    current_user = conn.assigns.current_user

    case Accounts.get_user_by_username(username) do
      nil ->
        {:error, :not_found}

      user ->
        json(conn, %{data: user_profile_json(user, current_user)})
    end
  end

  def posts(conn, %{"username" => username} = params) do
    current_user = conn.assigns.current_user

    case Accounts.get_user_by_username(username) do
      nil ->
        {:error, :not_found}

      user ->
        {cursor_id, cursor_time} = decode_cursor(params["cursor"])

        posts =
          Posts.list_posts_by_user(user.id,
            limit: @page_size,
            cursor_id: cursor_id,
            cursor_time: cursor_time
          )

        liked_post_ids = Posts.liked_post_ids_for_user(current_user.id, Enum.map(posts, & &1.id))
        next_cursor = encode_cursor(List.last(posts))

        json(conn, %{
          data: PostJSON.render_list(posts, %{liked_post_ids: liked_post_ids}),
          cursor: next_cursor
        })
    end
  end

  def follow(conn, %{"username" => username}) do
    current_user = conn.assigns.current_user

    case Accounts.get_user_by_username(username) do
      nil ->
        {:error, :not_found}

      user ->
        case Accounts.follow_user(current_user, user) do
          {:ok, _} -> json(conn, %{data: %{message: "followed"}})
          {:error, :cannot_follow_self} -> {:error, :forbidden}
        end
    end
  end

  def unfollow(conn, %{"username" => username}) do
    current_user = conn.assigns.current_user

    case Accounts.get_user_by_username(username) do
      nil ->
        {:error, :not_found}

      user ->
        Accounts.unfollow_user(current_user, user)
        json(conn, %{data: %{message: "unfollowed"}})
    end
  end

  defp user_profile_json(user, current_user) do
    %{
      id: user.id,
      username: user.username,
      bio: user.bio,
      profile_photo_url: user.profile_photo_url,
      post_count: Posts.get_post_count(user.id),
      follower_count: Accounts.get_follower_count(user.id),
      following_count: Accounts.get_following_count(user.id),
      followed_by_current_user: Accounts.following?(current_user.id, user.id)
    }
  end

  defp decode_cursor(nil), do: {nil, nil}

  defp decode_cursor(cursor) do
    case Base.url_decode64(cursor, padding: false) do
      {:ok, decoded} ->
        case String.split(decoded, ":", parts: 2) do
          [id_str, time_str] ->
            {String.to_integer(id_str), DateTime.from_iso8601(time_str) |> elem(1)}

          _ ->
            {nil, nil}
        end

      :error ->
        {nil, nil}
    end
  rescue
    _ -> {nil, nil}
  end

  defp encode_cursor(nil), do: nil

  defp encode_cursor(post) do
    Base.url_encode64("#{post.id}:#{DateTime.to_iso8601(post.inserted_at)}", padding: false)
  end
end
