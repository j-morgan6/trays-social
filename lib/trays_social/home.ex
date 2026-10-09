defmodule TraysSocial.Home do
  @moduledoc """
  The recipe-first Home screen: Jump back in, Tonight, Friends' trays, New from
  people you follow (finite), and suggested cooks for people who follow no one.
  See the recipe-first spec, section 3.

  Every section returns `type == "recipe"` posts only, skips deleted and
  moderator-removed posts, and hides users blocked in either direction.
  """

  import Ecto.Query, warn: false

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.Follow
  alias TraysSocial.Accounts.User
  alias TraysSocial.MealPlans
  alias TraysSocial.Posts.Bookmark
  alias TraysSocial.Posts.Post
  alias TraysSocial.Posts.RecipeOpen
  alias TraysSocial.Repo

  @jump_back_in_limit 6
  @friends_limit 10
  @new_window_days 7
  @new_limit 20
  @suggested_limit 5
  @suggested_window_days 30
  @post_preloads [:user, :ingredients, :tools, :cooking_steps, :post_tags, :post_photos]

  @doc """
  Assembles every Home section for `user`.

  `today` is the client's local calendar date and decides Tonight; it falls
  back to the server's UTC date only when the client sent none.
  """
  @spec build(User.t(), keyword()) :: map()
  def build(%User{id: user_id}, opts \\ []) do
    today = Keyword.get_lazy(opts, :today, &Date.utc_today/0)
    blocked_ids = Accounts.blocked_pair_ids(user_id)
    following_ids = Accounts.list_following_ids(user_id) -- blocked_ids

    %{
      jump_back_in: jump_back_in(user_id, blocked_ids),
      tonight: tonight(user_id, today, blocked_ids),
      friends_trays: friends_trays(user_id, blocked_ids),
      new_from_following: new_from_following(following_ids),
      suggested_cooks: suggested_cooks(following_ids, user_id, blocked_ids)
    }
  end

  defp live_recipes(query) do
    where(query, [p], is_nil(p.deleted_at) and is_nil(p.removed_at) and p.type == "recipe")
  end

  defp exclude_authors(query, []), do: query
  defp exclude_authors(query, ids), do: where(query, [p], p.user_id not in ^ids)

  defp exclude_followed(query, []), do: query
  defp exclude_followed(query, ids), do: where(query, [f], f.followed_id not in ^ids)

  # The tray is the user's own recipes plus the ones they bookmarked. Opened
  # recipes come first by last open; never-opened ones follow, newest first.
  defp jump_back_in(user_id, blocked_ids) do
    saved = from(b in Bookmark, where: b.post_id == parent_as(:post).id and b.user_id == ^user_id)

    from(p in Post, as: :post)
    |> live_recipes()
    |> where([p], p.user_id == ^user_id or exists(saved))
    |> exclude_authors(blocked_ids)
    |> join(:left, [p], o in RecipeOpen, on: o.post_id == p.id and o.user_id == ^user_id)
    |> order_by([p, o], desc_nulls_last: o.last_opened_at, desc: p.inserted_at, desc: p.id)
    |> limit(@jump_back_in_limit)
    |> Repo.all()
    |> Repo.preload(@post_preloads)
  end

  # list_entries/2 already drops deleted and removed posts; Home also drops
  # photo-only posts and anything a block now hides (blocks keep bookmarks and
  # meal-plan rows, so the entry can outlive the block).
  defp tonight(user_id, today, blocked_ids) do
    user_id
    |> MealPlans.list_entries(today)
    |> Enum.find(&tonight_entry?(&1, today, blocked_ids))
  end

  defp tonight_entry?(entry, today, blocked_ids) do
    entry.date == today and entry.post.type == "recipe" and
      entry.post.user_id not in blocked_ids
  end

  defp friends_trays(user_id, blocked_ids) do
    latest =
      Post
      |> live_recipes()
      |> group_by([p], p.user_id)
      |> select([p], %{
        user_id: p.user_id,
        last_posted_at: type(max(p.inserted_at), :utc_datetime)
      })

    query =
      from(f in Follow,
        join: u in User,
        on: u.id == f.followed_id,
        left_join: l in subquery(latest),
        on: l.user_id == u.id,
        where: f.follower_id == ^user_id,
        order_by: [desc_nulls_last: l.last_posted_at, desc: f.inserted_at, desc: f.id],
        limit: @friends_limit,
        select: %{user: u, last_posted_at: l.last_posted_at}
      )

    query
    |> exclude_followed(blocked_ids)
    |> Repo.all()
  end

  # Finite by design: no cursor, no pagination. following_ids already has
  # blocked users subtracted (build/2).
  defp new_from_following([]), do: []

  defp new_from_following(following_ids) do
    since = DateTime.utc_now() |> DateTime.add(-@new_window_days, :day)

    Post
    |> live_recipes()
    |> where([p], p.user_id in ^following_ids and p.inserted_at >= ^since)
    |> order_by([p], desc: p.inserted_at, desc: p.id)
    |> limit(@new_limit)
    |> Repo.all()
    |> Repo.preload(@post_preloads)
  end

  # Only for a viewer who follows no one (after blocks are subtracted).
  defp suggested_cooks([_ | _], _user_id, _blocked_ids), do: []

  defp suggested_cooks([], user_id, blocked_ids) do
    now = DateTime.utc_now()
    since = DateTime.add(now, -@suggested_window_days, :day)

    Post
    |> live_recipes()
    |> join(:inner, [p], u in User, on: u.id == p.user_id)
    |> where([p, u], p.inserted_at >= ^since and p.user_id != ^user_id)
    # Matches User.is_suspended?/1: suspended while suspended_until is in the future.
    |> where([p, u], is_nil(u.suspended_until) or u.suspended_until <= ^now)
    |> exclude_authors(blocked_ids)
    |> group_by([p, u], u.id)
    |> order_by([p, u], desc: count(p.id), asc: u.id)
    |> limit(@suggested_limit)
    |> select([p, u], %{user: u, recipe_count: count(p.id)})
    |> Repo.all()
  end
end
