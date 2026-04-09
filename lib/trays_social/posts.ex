defmodule TraysSocial.Posts do
  @moduledoc """
  The Posts context.
  """

  # Dialyzer false positives: Ecto.Multi.new() creates a concrete %MapSet{map: %{}}
  # but Ecto.Multi operations expect the opaque MapSet.internal(_) type.
  @dialyzer {:no_opaque, [like_post: 2, unlike_post: 2, create_comment: 3, delete_comment: 2]}

  import Ecto.Query, warn: false

  alias TraysSocial.Accounts.Follow
  alias TraysSocial.Notifications

  alias TraysSocial.Posts.Comment
  alias TraysSocial.Posts.CookingStep
  alias TraysSocial.Posts.Ingredient
  alias TraysSocial.Posts.Post
  alias TraysSocial.Posts.PostLike
  alias TraysSocial.Posts.PostPhoto
  alias TraysSocial.Posts.PostTag
  alias TraysSocial.Posts.Tool

  alias TraysSocial.Repo

  @doc """
  Returns the list of posts, excluding soft deleted posts.

  ## Examples

      iex> list_posts()
      [%Post{}, ...]

  """
  def list_posts(opts \\ []) do
    limit = Keyword.get(opts, :limit)
    cursor_id = Keyword.get(opts, :cursor_id)
    cursor_time = Keyword.get(opts, :cursor_time)
    for_user_id = Keyword.get(opts, :for_user_id)

    follow_count =
      if for_user_id do
        Follow |> where([f], f.follower_id == ^for_user_id) |> Repo.aggregate(:count)
      else
        0
      end

    personalized = for_user_id && follow_count >= 5

    Post
    |> where([p], is_nil(p.deleted_at))
    |> filter_followed_feed(for_user_id, personalized)
    |> cursor_where(cursor_id, cursor_time)
    |> order_by([p], desc: p.inserted_at, desc: p.id)
    |> then(fn q -> if limit, do: limit(q, ^limit), else: q end)
    |> preload([:user, :ingredients, :tools, :cooking_steps, :post_tags, :post_photos])
    |> Repo.all()
  end

  defp filter_followed_feed(query, _user_id, nil), do: query
  defp filter_followed_feed(query, _user_id, false), do: query

  defp filter_followed_feed(query, user_id, true) do
    join(query, :inner, [p], f in Follow,
      on: f.follower_id == ^user_id and f.followed_id == p.user_id
    )
  end

  defp cursor_where(query, nil, _), do: query

  defp cursor_where(query, cursor_id, cursor_time) do
    where(
      query,
      [p],
      p.inserted_at < ^cursor_time or (p.inserted_at == ^cursor_time and p.id < ^cursor_id)
    )
  end

  @doc """
  Returns trending posts (highest like_count), excluding soft deleted.
  """
  def list_trending_posts(limit \\ 10) do
    seven_days_ago = DateTime.utc_now() |> DateTime.add(-7, :day)

    Post
    |> where([p], is_nil(p.deleted_at) and p.inserted_at >= ^seven_days_ago)
    |> order_by([p], desc: p.like_count, desc: p.inserted_at)
    |> limit(^limit)
    |> preload([:user, :post_photos, :ingredients, :cooking_steps, :tools, :post_tags])
    |> Repo.all()
  end

  @doc """
  Returns the most recent posts, excluding soft deleted.
  """
  def list_recent_posts(limit \\ 10) do
    Post
    |> where([p], is_nil(p.deleted_at))
    |> order_by([p], desc: p.inserted_at)
    |> limit(^limit)
    |> preload([:user, :post_photos])
    |> Repo.all()
  end

  @doc """
  Returns the top N tags by post count.
  """
  def list_top_tags(limit \\ 6) do
    PostTag
    |> join(:inner, [pt], p in Post, on: p.id == pt.post_id and is_nil(p.deleted_at))
    |> group_by([pt], pt.tag)
    |> order_by([pt], desc: count(pt.id))
    |> limit(^limit)
    |> select([pt], pt.tag)
    |> Repo.all()
  end

  @doc """
  Searches posts by caption and tags. Supports cooking time filter and tag filter.
  Returns cursor-paginated results.
  """
  def search_posts(query_string, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    max_cooking_time = Keyword.get(opts, :max_cooking_time)
    tag = Keyword.get(opts, :tag)

    base =
      Post
      |> where([p], is_nil(p.deleted_at))
      |> order_by([p], desc: p.inserted_at)
      |> limit(^limit)
      |> preload([:user, :post_photos, :ingredients, :cooking_steps, :tools, :post_tags])

    base =
      if query_string && query_string != "" do
        sanitized = "%#{sanitize_like(query_string)}%"
        where(base, [p], ilike(p.caption, ^sanitized))
      else
        base
      end

    base =
      if max_cooking_time do
        where(base, [p], not is_nil(p.cooking_time_minutes) and p.cooking_time_minutes <= ^max_cooking_time)
      else
        base
      end

    base =
      if tag && tag != "" do
        base
        |> join(:inner, [p], pt in PostTag, on: pt.post_id == p.id and pt.tag == ^String.downcase(tag))
        |> distinct([p], p.id)
      else
        base
      end

    Repo.all(base)
  end

  defp sanitize_like(string) do
    string
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end

  @doc """
  Returns posts grouped by tag. Loads all posts for the given tags in one query,
  groups in Elixir, limiting to posts_per_tag per tag.
  Returns a list of {tag, posts} tuples in the same order as tags.
  """
  def list_posts_by_tags(tags, posts_per_tag \\ 8) do
    tag_post_ids =
      tags
      |> fetch_tag_post_rows()
      |> collect_post_ids_per_tag(posts_per_tag)

    posts_by_id = fetch_posts_by_ids(tag_post_ids)

    tags
    |> assemble_tag_posts(tag_post_ids, posts_by_id)
    |> Enum.reject(fn {_tag, posts} -> Enum.empty?(posts) end)
  end

  defp fetch_tag_post_rows(tags) do
    Post
    |> join(:inner, [p], pt in PostTag, on: pt.post_id == p.id and pt.tag in ^tags)
    |> where([p], is_nil(p.deleted_at))
    |> order_by([p, pt], asc: pt.tag, desc: p.inserted_at)
    |> select([p, pt], {pt.tag, p.id})
    |> Repo.all()
  end

  # Collect up to posts_per_tag post IDs per tag (order preserved)
  defp collect_post_ids_per_tag(rows, posts_per_tag) do
    Enum.reduce(rows, %{}, fn {tag, post_id}, acc ->
      current = Map.get(acc, tag, [])

      if length(current) < posts_per_tag do
        Map.put(acc, tag, current ++ [post_id])
      else
        acc
      end
    end)
  end

  defp fetch_posts_by_ids(tag_post_ids) do
    all_post_ids = tag_post_ids |> Map.values() |> List.flatten() |> Enum.uniq()

    Post
    |> where([p], p.id in ^all_post_ids)
    |> preload([:user, :post_photos])
    |> Repo.all()
    |> Map.new(&{&1.id, &1})
  end

  defp assemble_tag_posts(tags, tag_post_ids, posts_by_id) do
    Enum.map(tags, fn tag ->
      ids = Map.get(tag_post_ids, tag, [])
      posts = ids |> Enum.map(&Map.get(posts_by_id, &1)) |> Enum.reject(&is_nil/1)
      {tag, posts}
    end)
  end

  @doc """
  Returns the list of posts for a specific user, excluding soft deleted posts.

  ## Examples

      iex> list_posts_by_user(user_id)
      [%Post{}, ...]

  """
  def get_post_count(user_id) do
    Post
    |> where([p], p.user_id == ^user_id and is_nil(p.deleted_at))
    |> Repo.aggregate(:count)
  end

  def list_posts_by_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit)
    cursor_id = Keyword.get(opts, :cursor_id)
    cursor_time = Keyword.get(opts, :cursor_time)

    Post
    |> where([p], p.user_id == ^user_id and is_nil(p.deleted_at))
    |> cursor_where(cursor_id, cursor_time)
    |> order_by([p], desc: p.inserted_at, desc: p.id)
    |> then(fn q -> if limit, do: limit(q, ^limit), else: q end)
    |> preload([:user, :ingredients, :tools, :cooking_steps, :post_tags, :post_photos])
    |> Repo.all()
  end

  @doc """
  Gets a single post.

  Raises `Ecto.NoResultsError` if the Post does not exist or is deleted.

  ## Examples

      iex> get_post!(123)
      %Post{}

      iex> get_post!(456)
      ** (Ecto.NoResultsError)

  """
  def get_post!(id) do
    Post
    |> where([p], is_nil(p.deleted_at))
    |> preload([:user, :ingredients, :tools, :cooking_steps, :post_tags, :post_photos])
    |> Repo.get!(id)
  end

  @doc """
  Creates a post with nested associations.

  ## Examples

      iex> create_post(%{field: value})
      {:ok, %Post{}}

      iex> create_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_post(attrs \\ %{}) do
    %Post{}
    |> change_post(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a post.

  ## Examples

      iex> update_post(post, %{field: new_value})
      {:ok, %Post{}}

      iex> update_post(post, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Soft deletes a post by setting deleted_at timestamp.

  ## Examples

      iex> delete_post(post)
      {:ok, %Post{}}

      iex> delete_post(post)
      {:error, %Ecto.Changeset{}}

  """
  def delete_post(%Post{} = post) do
    post
    |> Ecto.Changeset.change(%{deleted_at: DateTime.utc_now(:second)})
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes, including
  nested association changesets for ingredients, tools, cooking steps, and tags.

  ## Examples

      iex> change_post(post)
      %Ecto.Changeset{data: %Post{}}

  """
  def change_post(%Post{} = post, attrs \\ %{}) do
    changeset =
      post
      |> Post.changeset(attrs)
      |> Ecto.Changeset.cast_assoc(:post_tags, with: &PostTag.changeset/2)
      |> Ecto.Changeset.cast_assoc(:post_photos, with: &PostPhoto.changeset/2)

    type = Ecto.Changeset.get_field(changeset, :type)

    if type == "recipe" do
      changeset
      |> Ecto.Changeset.cast_assoc(:ingredients, with: &Ingredient.changeset/2)
      |> Ecto.Changeset.cast_assoc(:tools, with: &Tool.changeset/2)
      |> Ecto.Changeset.cast_assoc(:cooking_steps, with: &CookingStep.changeset/2)
      |> validate_recipe_associations()
    else
      changeset
    end
  end

  defp validate_recipe_associations(changeset) do
    changeset
    |> validate_assoc_length(:ingredients, min: 1)
    |> validate_assoc_length(:cooking_steps, min: 1)
  end

  defp validate_assoc_length(changeset, field, opts) do
    min = Keyword.get(opts, :min, 0)
    assoc = Ecto.Changeset.get_field(changeset, field) || []

    if length(assoc) < min do
      Ecto.Changeset.add_error(changeset, field, "must have at least #{min}")
    else
      changeset
    end
  end

  @doc """
  Likes a post. Increments like_count atomically. No-op if already liked.
  """
  def like_post(%Post{} = post, user) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :like,
      PostLike.changeset(%PostLike{}, %{post_id: post.id, user_id: user.id}),
      on_conflict: :nothing,
      conflict_target: [:post_id, :user_id]
    )
    |> Ecto.Multi.run(:count, fn _repo, %{like: like} ->
      if like.id do
        {1, _} =
          Post
          |> where([p], p.id == ^post.id)
          |> Repo.update_all(inc: [like_count: 1])

        {:ok, post.like_count + 1}
      else
        {:ok, post.like_count}
      end
    end)
    |> Repo.transaction()
    |> tap(fn
      {:ok, %{like: like}} when not is_nil(like.id) ->
        Notifications.create_notification(%{
          type: "like",
          user_id: post.user_id,
          actor_id: user.id,
          post_id: post.id
        })

      _ ->
        :ok
    end)
  end

  @doc """
  Unlikes a post. Decrements like_count atomically. No-op if not liked.
  """
  def unlike_post(%Post{} = post, user) do
    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(
      :like,
      from(pl in PostLike, where: pl.post_id == ^post.id and pl.user_id == ^user.id)
    )
    |> Ecto.Multi.run(:count, fn _repo, %{like: {deleted, _}} ->
      if deleted > 0 do
        {1, _} =
          Post
          |> where([p], p.id == ^post.id)
          |> Repo.update_all(inc: [like_count: -1])

        {:ok, max(0, post.like_count - 1)}
      else
        {:ok, post.like_count}
      end
    end)
    |> Repo.transaction()
  end

  @doc """
  Returns true if the user has liked the post.
  """
  def liked_by?(post_id, user_id) do
    PostLike
    |> where([pl], pl.post_id == ^post_id and pl.user_id == ^user_id)
    |> Repo.exists?()
  end

  @doc """
  Returns a MapSet of post IDs (from the given list) that the user has liked.
  """
  def liked_post_ids_for_user(_user_id, []), do: MapSet.new()

  def liked_post_ids_for_user(user_id, post_ids) do
    PostLike
    |> where([pl], pl.user_id == ^user_id and pl.post_id in ^post_ids)
    |> select([pl], pl.post_id)
    |> Repo.all()
    |> MapSet.new()
  end

  @doc """
  Gets a single comment by ID. Raises if not found.
  """
  def get_comment!(id), do: Repo.get!(Comment, id)

  @doc """
  Returns non-deleted comments for a post, oldest first, with user preloaded.
  """
  def list_comments(post_id) do
    Comment
    |> where([c], c.post_id == ^post_id and is_nil(c.deleted_at))
    |> order_by([c], asc: c.inserted_at)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Returns cursor-paginated comments for a post, oldest first, with user preloaded.
  """
  def list_comments_paginated(post_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    cursor_id = Keyword.get(opts, :cursor_id)
    cursor_time = Keyword.get(opts, :cursor_time)

    query =
      Comment
      |> where([c], c.post_id == ^post_id and is_nil(c.deleted_at))
      |> order_by([c], asc: c.inserted_at, asc: c.id)
      |> limit(^limit)
      |> preload(:user)

    query =
      if cursor_id && cursor_time do
        where(
          query,
          [c],
          c.inserted_at > ^cursor_time or (c.inserted_at == ^cursor_time and c.id > ^cursor_id)
        )
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Creates a comment on a post and increments comment_count atomically.
  """
  def create_comment(%Post{} = post, user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :comment,
      Comment.changeset(%Comment{}, Map.merge(attrs, %{post_id: post.id, user_id: user.id}))
    )
    |> Ecto.Multi.run(:count, fn _repo, _changes ->
      {1, _} =
        Post
        |> where([p], p.id == ^post.id)
        |> Repo.update_all(inc: [comment_count: 1])

      {:ok, :incremented}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{comment: comment}} ->
        comment = Repo.preload(comment, :user)

        Notifications.create_notification(%{
          type: "comment",
          user_id: post.user_id,
          actor_id: user.id,
          post_id: post.id
        })

        {:ok, comment}

      {:error, :comment, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Soft-deletes a comment and decrements comment_count. Verifies ownership.
  """
  def delete_comment(%Comment{} = comment, user) do
    if comment.user_id == user.id do
      Ecto.Multi.new()
      |> Ecto.Multi.update(
        :comment,
        Ecto.Changeset.change(comment, deleted_at: DateTime.utc_now(:second))
      )
      |> Ecto.Multi.run(:count, fn _repo, _changes ->
        {1, _} =
          Post
          |> where([p], p.id == ^comment.post_id)
          |> Repo.update_all(inc: [comment_count: -1])

        {:ok, :decremented}
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{comment: comment}} -> {:ok, comment}
        {:error, _, reason, _} -> {:error, reason}
      end
    else
      {:error, :unauthorized}
    end
  end

  ## Bookmarks

  alias TraysSocial.Posts.Bookmark

  @doc """
  Bookmarks a post for a user (saves to My Tray).
  """
  def create_bookmark(user_id, post_id) do
    %Bookmark{}
    |> Bookmark.changeset(%{user_id: user_id, post_id: post_id})
    |> Repo.insert()
  end

  @doc """
  Removes a bookmark.
  """
  def delete_bookmark(user_id, post_id) do
    case Repo.get_by(Bookmark, user_id: user_id, post_id: post_id) do
      nil -> {:error, :not_found}
      bookmark -> Repo.delete(bookmark)
    end
  end

  @doc """
  Lists bookmarked posts for a user with cursor pagination, newest first.
  """
  def list_bookmarks(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    cursor_id = Keyword.get(opts, :cursor_id)
    cursor_time = Keyword.get(opts, :cursor_time)

    query =
      Bookmark
      |> where([b], b.user_id == ^user_id)
      |> join(:inner, [b], p in Post, on: b.post_id == p.id and is_nil(p.deleted_at))
      |> order_by([b], desc: b.inserted_at, desc: b.id)
      |> limit(^limit)
      |> preload([b, p], post: {p, [:user, :post_photos, :ingredients, :cooking_steps, :tools, :post_tags]})

    query =
      if cursor_id && cursor_time do
        where(
          query,
          [b],
          b.inserted_at < ^cursor_time or (b.inserted_at == ^cursor_time and b.id < ^cursor_id)
        )
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Returns true if the user has bookmarked the post.
  """
  def bookmarked?(user_id, post_id) do
    Bookmark
    |> where([b], b.user_id == ^user_id and b.post_id == ^post_id)
    |> Repo.exists?()
  end

  @doc """
  Returns a MapSet of post IDs (from the given list) that the user has bookmarked.
  """
  def bookmarked_post_ids_for_user(_user_id, []), do: MapSet.new()

  def bookmarked_post_ids_for_user(user_id, post_ids) do
    Bookmark
    |> where([b], b.user_id == ^user_id and b.post_id in ^post_ids)
    |> select([b], b.post_id)
    |> Repo.all()
    |> MapSet.new()
  end

  @doc """
  Returns the count of bookmarks on posts authored by the given user.
  """
  def save_count_for_user(user_id) do
    Bookmark
    |> join(:inner, [b], p in Post, on: b.post_id == p.id)
    |> where([b, p], p.user_id == ^user_id)
    |> Repo.aggregate(:count)
  end
end
