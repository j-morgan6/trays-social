defmodule TraysSocialWeb.API.V1.CommentController do
  use TraysSocialWeb, :controller

  action_fallback TraysSocialWeb.API.V1.FallbackController

  alias TraysSocial.Posts
  alias TraysSocialWeb.API.V1.JSON.CommentJSON

  @page_size 20

  def index(conn, %{"post_id" => post_id} = params) do
    {cursor_id, cursor_time} = decode_cursor(params["cursor"])

    try do
      _post = Posts.get_post!(post_id)

      comments =
        Posts.list_comments_paginated(post_id,
          limit: @page_size,
          cursor_id: cursor_id,
          cursor_time: cursor_time
        )

      next_cursor = encode_cursor(List.last(comments))

      json(conn, %{
        data: CommentJSON.render_list(comments),
        cursor: next_cursor
      })
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
      Ecto.Query.CastError -> {:error, :not_found}
    end
  end

  def create(conn, %{"post_id" => post_id} = params) do
    user = conn.assigns.current_user

    try do
      post = Posts.get_post!(post_id)

      case Posts.create_comment(post, user, %{body: params["body"]}) do
        {:ok, comment} ->
          conn
          |> put_status(:created)
          |> json(%{data: CommentJSON.render(comment)})

        {:error, changeset} ->
          {:error, changeset}
      end
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
      Ecto.Query.CastError -> {:error, :not_found}
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    try do
      comment = Posts.get_comment!(id)

      case Posts.delete_comment(comment, user) do
        {:ok, comment} ->
          comment = TraysSocial.Repo.preload(comment, :user)
          json(conn, %{data: CommentJSON.render(comment)})

        {:error, :unauthorized} ->
          {:error, :forbidden}
      end
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
      Ecto.Query.CastError -> {:error, :not_found}
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

  defp encode_cursor(comment) do
    Base.url_encode64("#{comment.id}:#{DateTime.to_iso8601(comment.inserted_at)}", padding: false)
  end
end
