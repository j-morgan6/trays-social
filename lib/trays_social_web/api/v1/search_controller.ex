defmodule TraysSocialWeb.API.V1.SearchController do
  use TraysSocialWeb, :controller

  alias TraysSocial.Posts
  alias TraysSocial.Accounts
  alias TraysSocialWeb.API.V1.JSON.PostJSON

  @max_query_length 100
  @max_tag_length 50

  def index(conn, params) do
    user = conn.assigns.current_user
    query = sanitize(params["q"], @max_query_length) || ""
    max_cooking_time = parse_int(params["max_cooking_time"])
    tag = sanitize(params["tag"], @max_tag_length)
    blocked_ids = Accounts.blocked_pair_ids(user.id)
    {cursor_id, cursor_time} = decode_cursor(params["cursor"])

    posts =
      Posts.search_posts(query,
        limit: 20,
        max_cooking_time: max_cooking_time,
        tag: tag,
        blocked_user_ids: blocked_ids,
        cursor_id: cursor_id,
        cursor_time: cursor_time
      )

    users =
      if tag || max_cooking_time do
        []
      else
        Accounts.search_users(query, limit: 10, blocked_user_ids: blocked_ids)
      end

    post_ids = Enum.map(posts, & &1.id)
    liked_post_ids = Posts.liked_post_ids_for_user(user.id, post_ids)
    bookmarked_post_ids = Posts.bookmarked_post_ids_for_user(user.id, post_ids)

    json(conn, %{
      data: %{
        posts: PostJSON.render_list(posts, %{liked_post_ids: liked_post_ids, bookmarked_post_ids: bookmarked_post_ids}),
        users: Enum.map(users, &render_user/1)
      },
      cursor: encode_cursor(List.last(posts))
    })
  end

  # D107: strict decode — malformed input degrades to page 1 instead of
  # leaking Ecto.Query.CastError / DBConnection.EncodeError as 500s (the
  # elem(1)-on-error-tuple hazard flagged in the 2026-07-02 review).
  defp decode_cursor(nil), do: {nil, nil}

  defp decode_cursor(cursor) when is_binary(cursor) do
    with {:ok, decoded} <- Base.url_decode64(cursor, padding: false),
         [id_str, time_str] <- String.split(decoded, ":", parts: 2),
         {id, ""} when id > 0 and id < 9_223_372_036_854_775_807 <- Integer.parse(id_str),
         {:ok, time, _offset} <- DateTime.from_iso8601(time_str) do
      {id, time}
    else
      _ -> {nil, nil}
    end
  end

  defp decode_cursor(_), do: {nil, nil}

  defp encode_cursor(nil), do: nil

  defp encode_cursor(post) do
    Base.url_encode64("#{post.id}:#{DateTime.to_iso8601(post.inserted_at)}", padding: false)
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
  defp parse_int(_), do: nil

  defp sanitize(nil, _max), do: nil
  defp sanitize(value, max) when is_binary(value) do
    case value |> String.trim() |> String.slice(0, max) do
      "" -> nil
      trimmed -> trimmed
    end
  end
  defp sanitize(_, _), do: nil
end
