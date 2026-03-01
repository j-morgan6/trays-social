defmodule TraysSocial.Posts do
  @moduledoc """
  The Posts context.
  """

  import Ecto.Query, warn: false
  alias TraysSocial.Repo

  alias TraysSocial.Posts.{Post, Ingredient, Tool, CookingStep, PostTag, PostPhoto, PostLike, Comment}
  alias TraysSocial.Accounts.Follow
  alias TraysSocial.Notifications

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

    personalized = for_user_id && Repo.exists?(from(f in Follow, where: f.follower_id == ^for_user_id))

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
    join(query, :inner, [p], f in Follow, on: f.follower_id == ^user_id and f.followed_id == p.user_id)
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
    Post
    |> where([p], is_nil(p.deleted_at))
    |> order_by([p], desc: p.like_count, desc: p.inserted_at)
    |> limit(^limit)
    |> preload([:user, :post_photos])
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
  Returns posts grouped by tag. Loads all posts for the given tags in one query,
  groups in Elixir, limiting to posts_per_tag per tag.
  Returns a list of {tag, posts} tuples in the same order as tags.
  """
  def list_posts_by_tags(tags, posts_per_tag \\ 8) do
    rows =
      Post
      |> join(:inner, [p], pt in PostTag, on: pt.post_id == p.id and pt.tag in ^tags)
      |> where([p], is_nil(p.deleted_at))
      |> order_by([p, pt], [asc: pt.tag, desc: p.inserted_at])
      |> select([p, pt], {pt.tag, p.id})
      |> Repo.all()

    # Collect up to posts_per_tag post IDs per tag (order preserved)
    tag_post_ids =
      Enum.reduce(rows, %{}, fn {tag, post_id}, acc ->
        current = Map.get(acc, tag, [])
        if length(current) < posts_per_tag do
          Map.put(acc, tag, current ++ [post_id])
        else
          acc
        end
      end)

    all_post_ids = tag_post_ids |> Map.values() |> List.flatten() |> Enum.uniq()

    posts_by_id =
      Post
      |> where([p], p.id in ^all_post_ids)
      |> preload([:user, :post_photos])
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    Enum.map(tags, fn tag ->
      ids = Map.get(tag_post_ids, tag, [])
      posts = Enum.map(ids, &Map.get(posts_by_id, &1)) |> Enum.reject(&is_nil/1)
      {tag, posts}
    end)
    |> Enum.reject(fn {_tag, posts} -> Enum.empty?(posts) end)
  end

  @doc """
  Returns the list of posts for a specific user, excluding soft deleted posts.

  ## Examples

      iex> list_posts_by_user(user_id)
      [%Post{}, ...]

  """
  def list_posts_by_user(user_id) do
    Post
    |> where([p], p.user_id == ^user_id and is_nil(p.deleted_at))
    |> order_by([p], desc: p.inserted_at)
    |> preload([:user])
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
    post
    |> Post.changeset(attrs)
    |> Ecto.Changeset.cast_assoc(:ingredients, with: &Ingredient.changeset/2)
    |> Ecto.Changeset.cast_assoc(:tools, with: &Tool.changeset/2)
    |> Ecto.Changeset.cast_assoc(:cooking_steps, with: &CookingStep.changeset/2)
    |> Ecto.Changeset.cast_assoc(:post_tags, with: &PostTag.changeset/2)
    |> Ecto.Changeset.cast_assoc(:post_photos, with: &PostPhoto.changeset/2)
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
        {1, _} = Repo.update_all(from(p in Post, where: p.id == ^post.id), inc: [like_count: 1])
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
          Repo.update_all(
            from(p in Post, where: p.id == ^post.id),
            inc: [like_count: -1]
          )

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
  Creates a comment on a post and increments comment_count atomically.
  """
  def create_comment(%Post{} = post, user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :comment,
      Comment.changeset(%Comment{}, Map.merge(attrs, %{post_id: post.id, user_id: user.id}))
    )
    |> Ecto.Multi.run(:count, fn _repo, _changes ->
      {1, _} = Repo.update_all(from(p in Post, where: p.id == ^post.id), inc: [comment_count: 1])
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
          Repo.update_all(
            from(p in Post, where: p.id == ^comment.post_id),
            inc: [comment_count: -1]
          )

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
end
