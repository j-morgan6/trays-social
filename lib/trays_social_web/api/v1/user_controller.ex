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
        # W167: profiles are invisible across a block in either direction.
        # 404 (not 403) so blocks aren't enumerable.
        if Accounts.blocked_between?(current_user.id, user.id) do
          {:error, :not_found}
        else
          json(conn, %{data: user_profile_json(user, current_user)})
        end
    end
  end

  def posts(conn, %{"username" => username} = params) do
    current_user = conn.assigns.current_user

    case Accounts.get_user_by_username(username) do
      nil ->
        {:error, :not_found}

      user ->
        # W167: a blocked pair can't read each other's posts (404 like show).
        if Accounts.blocked_between?(current_user.id, user.id) do
          {:error, :not_found}
        else
          {cursor_id, cursor_time} = decode_cursor(params["cursor"])

          posts =
            Posts.list_posts_by_user(user.id,
              limit: @page_size,
              cursor_id: cursor_id,
              cursor_time: cursor_time,
              filter: params["filter"]
            )

          liked_post_ids =
            Posts.liked_post_ids_for_user(current_user.id, Enum.map(posts, & &1.id))

          next_cursor = encode_cursor(List.last(posts))

          json(conn, %{
            data: PostJSON.render_list(posts, %{liked_post_ids: liked_post_ids}),
            cursor: next_cursor
          })
        end
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
          {:error, :blocked} -> {:error, :blocked}
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

  def followers(conn, %{"username" => username}) do
    current_user = conn.assigns.current_user

    case Accounts.get_user_by_username(username) do
      nil ->
        {:error, :not_found}

      user ->
        entries =
          Accounts.list_followers(user.id,
            limit: @page_size,
            cursor: decode_follow_cursor(conn.params["cursor"]),
            blocked_user_ids: Accounts.blocked_pair_ids(current_user.id)
          )

        json(conn, %{
          data: Enum.map(entries, &user_list_json(&1.user, current_user)),
          cursor: encode_follow_cursor(List.last(entries))
        })
    end
  end

  def following(conn, %{"username" => username}) do
    current_user = conn.assigns.current_user

    case Accounts.get_user_by_username(username) do
      nil ->
        {:error, :not_found}

      user ->
        entries =
          Accounts.list_following(user.id,
            limit: @page_size,
            cursor: decode_follow_cursor(conn.params["cursor"]),
            blocked_user_ids: Accounts.blocked_pair_ids(current_user.id)
          )

        json(conn, %{
          data: Enum.map(entries, &user_list_json(&1.user, current_user)),
          cursor: encode_follow_cursor(List.last(entries))
        })
    end
  end

  def block(conn, %{"username" => username}) do
    current_user = conn.assigns.current_user

    case Accounts.get_user_by_username(username) do
      nil ->
        {:error, :not_found}

      user ->
        case Accounts.block_user(current_user.id, user.id) do
          {:ok, _} ->
            json(conn, %{data: %{message: "User blocked"}})

          {:error, changeset} ->
            errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
            conn |> put_status(:unprocessable_entity) |> json(%{errors: errors})
        end
    end
  end

  def unblock(conn, %{"username" => username}) do
    current_user = conn.assigns.current_user

    case Accounts.get_user_by_username(username) do
      nil ->
        {:error, :not_found}

      user ->
        Accounts.unblock_user(current_user.id, user.id)
        json(conn, %{data: %{message: "User unblocked"}})
    end
  end

  def update_muted_keywords(conn, %{"keywords" => keywords}) when is_list(keywords) do
    current_user = conn.assigns.current_user
    user = Accounts.get_user!(current_user.id)

    case Accounts.set_muted_keywords(user, keywords) do
      {:ok, updated} ->
        json(conn, %{data: %{muted_keywords: updated.muted_keywords}})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: %{keywords: ["invalid"]}})
    end
  end

  def list_blocked_users(conn, _params) do
    current_user = conn.assigns.current_user
    blocked = Accounts.list_blocked_users(current_user.id)

    json(conn, %{
      data:
        Enum.map(blocked, fn u ->
          %{id: u.id, username: u.username, profile_photo_url: u.profile_photo_url}
        end)
    })
  end

  def muted_keywords(conn, _params) do
    current_user = conn.assigns.current_user
    keywords = Accounts.get_muted_keywords(current_user.id)
    json(conn, %{data: %{muted_keywords: keywords}})
  end

  defp user_list_json(user, current_user) do
    %{
      id: user.id,
      username: user.username,
      bio: user.bio,
      profile_photo_url: user.profile_photo_url,
      followed_by_current_user: Accounts.following?(current_user.id, user.id)
    }
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

  # D109: strict decode — malformed cursors degrade to page 1 instead of
  # leaking Ecto/DBConnection errors as 500s. Cursor encodes the FOLLOW
  # row's (id, inserted_at), the columns the listing orders by.
  defp decode_follow_cursor(nil), do: nil

  defp decode_follow_cursor(cursor) when is_binary(cursor) do
    with {:ok, decoded} <- Base.url_decode64(cursor, padding: false),
         [id_str, time_str] <- String.split(decoded, ":", parts: 2),
         {id, ""} when id > 0 and id < 9_223_372_036_854_775_807 <- Integer.parse(id_str),
         {:ok, time, _offset} <- DateTime.from_iso8601(time_str) do
      {time, id}
    else
      _ -> nil
    end
  end

  defp decode_follow_cursor(_), do: nil

  defp encode_follow_cursor(nil), do: nil

  defp encode_follow_cursor(entry) do
    Base.url_encode64("#{entry.follow_id}:#{DateTime.to_iso8601(entry.followed_at)}",
      padding: false
    )
  end
end
