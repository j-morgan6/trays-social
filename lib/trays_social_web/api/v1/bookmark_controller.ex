defmodule TraysSocialWeb.API.V1.BookmarkController do
  use TraysSocialWeb, :controller

  action_fallback TraysSocialWeb.API.V1.FallbackController

  alias TraysSocial.Posts
  alias TraysSocialWeb.API.V1.JSON.PostJSON

  @page_size 20

  def index(conn, params) do
    user = conn.assigns.current_user
    {cursor_id, cursor_time} = decode_cursor(params["cursor"])

    bookmarks =
      Posts.list_bookmarks(user.id, limit: @page_size, cursor_id: cursor_id, cursor_time: cursor_time)

    posts = Enum.map(bookmarks, & &1.post)
    liked_post_ids = Posts.liked_post_ids_for_user(user.id, Enum.map(posts, & &1.id))
    bookmarked_post_ids = Posts.bookmarked_post_ids_for_user(user.id, Enum.map(posts, & &1.id))
    next_cursor = encode_cursor(List.last(bookmarks))

    json(conn, %{
      data: PostJSON.render_list(posts, %{liked_post_ids: liked_post_ids, bookmarked_post_ids: bookmarked_post_ids}),
      cursor: next_cursor
    })
  end

  def create(conn, %{"post_id" => post_id}) do
    user = conn.assigns.current_user

    try do
      _post = Posts.get_post!(post_id)

      case Posts.create_bookmark(user.id, post_id) do
        {:ok, _bookmark} ->
          conn
          |> put_status(:created)
          |> json(%{data: %{message: "saved to tray"}})

        {:error, changeset} ->
          {:error, changeset}
      end
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
      Ecto.Query.CastError -> {:error, :not_found}
    end
  end

  def delete(conn, %{"post_id" => post_id}) do
    user = conn.assigns.current_user

    case Posts.delete_bookmark(user.id, post_id) do
      {:ok, _} -> json(conn, %{data: %{message: "removed from tray"}})
      {:error, :not_found} -> {:error, :not_found}
    end
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

  defp encode_cursor(bookmark) do
    Base.url_encode64("#{bookmark.id}:#{DateTime.to_iso8601(bookmark.inserted_at)}", padding: false)
  end
end
