defmodule TraysSocial.Collections do
  @moduledoc """
  W172: named collections of saved recipes — the Trays Plus organizational
  layer on top of bookmarks.

  A collection belongs to a user and holds references to posts the user has
  bookmarked or authored. Collections never own content: deleting a
  collection deletes only the collection and its membership rows, never the
  underlying bookmarks or posts.

  Subscription gating (Trays Plus) lives in the web layer
  (`TraysSocialWeb.API.V1.CollectionController`), NOT here. This context
  always performs the requested operation so that lapsed subscribers keep
  read and delete access to their own data (graceful re-lock).
  """

  import Ecto.Query, warn: false

  alias TraysSocial.Accounts.User
  alias TraysSocial.Collections.Collection
  alias TraysSocial.Collections.CollectionItem
  alias TraysSocial.Posts
  alias TraysSocial.Posts.Post
  alias TraysSocial.Posts.PostPhoto
  alias TraysSocial.Repo

  @doc """
  Lists the user's collections, newest first, each as a summary map:

      %{collection: %Collection{}, item_count: 3, cover_photo_url: "..." | nil}

  `item_count` and `cover_photo_url` only consider member posts that are
  neither soft-deleted nor moderator-removed.
  """
  def list_collections(user_id) do
    collections =
      Collection
      |> where([c], c.user_id == ^user_id)
      |> order_by([c], desc: c.inserted_at, desc: c.id)
      |> Repo.all()

    counts = item_counts(Enum.map(collections, & &1.id))

    Enum.map(collections, fn collection ->
      %{
        collection: collection,
        item_count: Map.get(counts, collection.id, 0),
        cover_photo_url: cover_photo_url(collection.id)
      }
    end)
  end

  @doc """
  Builds the summary map (see `list_collections/1`) for a single collection.
  """
  def collection_summary(%Collection{} = collection) do
    %{
      collection: collection,
      item_count: [collection.id] |> item_counts() |> Map.get(collection.id, 0),
      cover_photo_url: cover_photo_url(collection.id)
    }
  end

  @doc """
  Fetches the user's collection or raises `Ecto.NoResultsError`.

  Scoped by owner so another user's collection is indistinguishable from a
  missing one (404, never 403).
  """
  def get_collection!(user_id, id) do
    Repo.get_by!(Collection, id: id, user_id: user_id)
  end

  @doc """
  Creates a collection for the user.
  """
  def create_collection(user_id, attrs) do
    %Collection{user_id: user_id}
    |> Collection.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Renames a collection.
  """
  def rename_collection(%Collection{} = collection, attrs) do
    collection
    |> Collection.rename_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a collection. Membership rows go with it (on_delete: :delete_all);
  the underlying bookmarks and posts are untouched.
  """
  def delete_collection(%Collection{} = collection) do
    Repo.delete(collection)
  end

  @doc """
  Adds a post to a collection.

  Only posts the user has bookmarked or authored may be added — a collection
  organizes the user's own tray, it is not a second save mechanism. Returns
  `{:error, :forbidden}` otherwise.
  """
  def add_post(%User{} = user, %Collection{} = collection, %Post{} = post) do
    if post.user_id == user.id or Posts.bookmarked?(user.id, post.id) do
      %CollectionItem{}
      |> CollectionItem.changeset(%{collection_id: collection.id, post_id: post.id})
      |> Repo.insert()
    else
      {:error, :forbidden}
    end
  end

  @doc """
  Removes a post from a collection.
  """
  def remove_post(%Collection{} = collection, post_id) do
    case Repo.get_by(CollectionItem, collection_id: collection.id, post_id: post_id) do
      nil -> {:error, :not_found}
      item -> Repo.delete(item)
    end
  end

  @doc """
  Lists a collection's items with cursor pagination, newest first, with each
  item's post preloaded for `PostJSON`. Soft-deleted and moderator-removed
  posts never appear.

  Options: `:limit` (default 20), `:cursor_id`, `:cursor_time` — the cursor
  is keyed off the collection_items row (id, inserted_at), mirroring
  `Posts.list_bookmarks/2`.
  """
  def list_collection_items(collection_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    cursor_id = Keyword.get(opts, :cursor_id)
    cursor_time = Keyword.get(opts, :cursor_time)

    query =
      CollectionItem
      |> where([ci], ci.collection_id == ^collection_id)
      |> join(:inner, [ci], p in Post,
        on: ci.post_id == p.id and is_nil(p.deleted_at) and is_nil(p.removed_at)
      )
      |> order_by([ci], desc: ci.inserted_at, desc: ci.id)
      |> limit(^limit)
      |> preload([ci, p],
        post: {p, [:user, :post_photos, :ingredients, :cooking_steps, :tools, :post_tags]}
      )

    query =
      if cursor_id && cursor_time do
        where(
          query,
          [ci],
          ci.inserted_at < ^cursor_time or
            (ci.inserted_at == ^cursor_time and ci.id < ^cursor_id)
        )
      else
        query
      end

    Repo.all(query)
  end

  # Grouped live-item counts for a set of collections. The join repeats the
  # soft-delete filter so counts always match what listings render.
  defp item_counts([]), do: %{}

  defp item_counts(collection_ids) do
    CollectionItem
    |> where([ci], ci.collection_id in ^collection_ids)
    |> join(:inner, [ci], p in Post,
      on: ci.post_id == p.id and is_nil(p.deleted_at) and is_nil(p.removed_at)
    )
    |> group_by([ci], ci.collection_id)
    |> select([ci], {ci.collection_id, count(ci.id)})
    |> Repo.all()
    |> Map.new()
  end

  # The cover is the position-0 photo of the most recently added live member
  # post. Left join on photos: a newest member without photos yields nil
  # rather than falling back to an older post.
  defp cover_photo_url(collection_id) do
    CollectionItem
    |> where([ci], ci.collection_id == ^collection_id)
    |> join(:inner, [ci], p in Post,
      on: ci.post_id == p.id and is_nil(p.deleted_at) and is_nil(p.removed_at)
    )
    |> join(:left, [ci, p], ph in PostPhoto, on: ph.post_id == p.id and ph.position == 0)
    |> order_by([ci], desc: ci.inserted_at, desc: ci.id)
    |> limit(1)
    |> select([ci, p, ph], ph.url)
    |> Repo.one()
  end
end
