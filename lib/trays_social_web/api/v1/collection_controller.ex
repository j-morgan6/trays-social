defmodule TraysSocialWeb.API.V1.CollectionController do
  use TraysSocialWeb, :controller

  action_fallback TraysSocialWeb.API.V1.FallbackController

  alias TraysSocial.Collections
  alias TraysSocial.Monetization
  alias TraysSocial.Posts
  alias TraysSocialWeb.API.V1.JSON.CollectionJSON
  alias TraysSocialWeb.API.V1.JSON.PostJSON

  @page_size 20

  # W172 Trays Plus gating: creating, renaming, and adding to collections
  # require an active subscription while the paid tier is enabled. Reads,
  # collection deletes, and item removals are NEVER gated — a lapsed
  # subscriber keeps full access to their own data (graceful re-lock).

  def index(conn, _params) do
    user = conn.assigns.current_user

    summaries = user.id |> Collections.list_collections() |> CollectionJSON.render_list()

    json(conn, %{data: summaries})
  end

  def show(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    try do
      collection = Collections.get_collection!(user.id, id)
      {cursor_id, cursor_time} = decode_cursor(params["cursor"])

      items =
        Collections.list_collection_items(collection.id,
          limit: @page_size,
          cursor_id: cursor_id,
          cursor_time: cursor_time
        )

      posts = Enum.map(items, & &1.post)
      post_ids = Enum.map(posts, & &1.id)
      liked_post_ids = Posts.liked_post_ids_for_user(user.id, post_ids)
      bookmarked_post_ids = Posts.bookmarked_post_ids_for_user(user.id, post_ids)
      next_cursor = encode_cursor(List.last(items))

      json(conn, %{
        data:
          PostJSON.render_list(posts, %{
            liked_post_ids: liked_post_ids,
            bookmarked_post_ids: bookmarked_post_ids
          }),
        cursor: next_cursor
      })
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
      Ecto.Query.CastError -> {:error, :not_found}
    end
  end

  def create(conn, params) do
    user = conn.assigns.current_user

    with :ok <- require_subscription(user),
         {:ok, collection} <- Collections.create_collection(user.id, %{name: params["name"]}) do
      conn
      |> put_status(:created)
      |> json(%{data: collection |> Collections.collection_summary() |> CollectionJSON.render()})
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    with :ok <- require_subscription(user) do
      try do
        collection = Collections.get_collection!(user.id, id)

        with {:ok, collection} <-
               Collections.rename_collection(collection, %{name: params["name"]}) do
          json(conn, %{
            data: collection |> Collections.collection_summary() |> CollectionJSON.render()
          })
        end
      rescue
        Ecto.NoResultsError -> {:error, :not_found}
        Ecto.Query.CastError -> {:error, :not_found}
      end
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    try do
      collection = Collections.get_collection!(user.id, id)
      {:ok, _} = Collections.delete_collection(collection)
      json(conn, %{data: %{message: "collection deleted"}})
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
      Ecto.Query.CastError -> {:error, :not_found}
    end
  end

  def add_post(conn, %{"id" => id, "post_id" => post_id}) do
    user = conn.assigns.current_user

    with :ok <- require_subscription(user) do
      try do
        collection = Collections.get_collection!(user.id, id)
        post = Posts.get_post!(post_id)

        case Collections.add_post(user, collection, post) do
          {:ok, _item} ->
            conn
            |> put_status(:created)
            |> json(%{data: %{message: "added to collection"}})

          {:error, _} = error ->
            error
        end
      rescue
        Ecto.NoResultsError -> {:error, :not_found}
        Ecto.Query.CastError -> {:error, :not_found}
      end
    end
  end

  def remove_post(conn, %{"id" => id, "post_id" => post_id}) do
    user = conn.assigns.current_user

    try do
      collection = Collections.get_collection!(user.id, id)

      case Collections.remove_post(collection, post_id) do
        {:ok, _} -> json(conn, %{data: %{message: "removed from collection"}})
        {:error, :not_found} -> {:error, :not_found}
      end
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
      Ecto.Query.CastError -> {:error, :not_found}
    end
  end

  defp require_subscription(user) do
    if Monetization.feature_enabled?(:paid_tier) and Monetization.subscriber?(user) do
      :ok
    else
      {:error, :subscription_required}
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

  defp encode_cursor(item) do
    Base.url_encode64("#{item.id}:#{DateTime.to_iso8601(item.inserted_at)}",
      padding: false
    )
  end
end
