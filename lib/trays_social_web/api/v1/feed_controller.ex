defmodule TraysSocialWeb.API.V1.FeedController do
  use TraysSocialWeb, :controller

  alias TraysSocial.Posts
  alias TraysSocialWeb.API.V1.JSON.PostJSON

  @page_size 20

  def index(conn, params) do
    user = conn.assigns.current_user
    {cursor_id, cursor_time} = decode_cursor(params["cursor"])

    posts =
      Posts.list_posts(
        for_user_id: user.id,
        limit: @page_size,
        cursor_id: cursor_id,
        cursor_time: cursor_time
      )

    liked_post_ids = Posts.liked_post_ids_for_user(user.id, Enum.map(posts, & &1.id))
    next_cursor = encode_cursor(List.last(posts))

    json(conn, %{
      data: PostJSON.render_list(posts, %{liked_post_ids: liked_post_ids}),
      cursor: next_cursor
    })
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
