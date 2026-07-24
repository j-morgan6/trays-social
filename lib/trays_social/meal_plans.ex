defmodule TraysSocial.MealPlans do
  @moduledoc """
  W173: weekly meal planner + derived grocery checklist — the Trays Plus
  planning layer on top of the user's own and bookmarked recipes.

  An entry pins a post to an exact date; week-scoped reads normalize any
  given date to that week's Monday (`Date.beginning_of_week/1`) and cover
  the 7-day window [monday, monday + 6]. Grocery items are DERIVED from the
  planned posts' ingredients at read time — nothing shoppable is stored.
  Checks are the only grocery state: one row per (user, week, item_key),
  keyed by the stable "post_id:ingredient_id" item key.

  The grocery list is deliberately plain: no unit aggregation, no merging
  across recipes — one group per planned recipe, items in recipe order.

  Subscription gating (Trays Plus) lives in the web layer
  (`TraysSocialWeb.API.V1.MealPlanController`), NOT here. This context
  always performs the requested operation so that lapsed subscribers keep
  read, delete, and check access to their own data (graceful re-lock).
  """

  import Ecto.Query, warn: false

  alias TraysSocial.Accounts.User
  alias TraysSocial.MealPlans.GroceryCheck
  alias TraysSocial.MealPlans.MealPlanEntry
  alias TraysSocial.Posts
  alias TraysSocial.Posts.Ingredient
  alias TraysSocial.Posts.Post
  alias TraysSocial.Posts.PostPhoto
  alias TraysSocial.Repo
  alias TraysSocial.Uploads.ImageProcessor

  @doc """
  Lists the user's entries for the week containing `week_start`, ordered by
  date then id, each with its post (and the post's photos) preloaded.

  Entries whose post has been soft-deleted or moderator-removed never
  appear.
  """
  def list_entries(user_id, %Date{} = week_start) do
    {monday, sunday} = week_window(week_start)

    MealPlanEntry
    |> where([e], e.user_id == ^user_id)
    |> where([e], e.date >= ^monday and e.date <= ^sunday)
    |> join(:inner, [e], p in Post,
      on: e.post_id == p.id and is_nil(p.deleted_at) and is_nil(p.removed_at)
    )
    |> order_by([e], asc: e.date, asc: e.id)
    |> preload(post: :post_photos)
    |> Repo.all()
  end

  @doc """
  Plans a post for a date.

  Only posts the user has bookmarked or authored may be planned — the meal
  plan schedules the user's own tray, it is not a second save mechanism.
  Returns `{:error, :forbidden}` otherwise. The exact date is stored;
  normalization to Monday happens only on week-scoped reads.
  """
  def create_entry(%User{} = user, %Date{} = date, %Post{} = post) do
    if post.user_id == user.id or Posts.bookmarked?(user.id, post.id) do
      %MealPlanEntry{}
      |> MealPlanEntry.changeset(%{user_id: user.id, date: date, post_id: post.id})
      |> Repo.insert()
    else
      {:error, :forbidden}
    end
  end

  @doc """
  Deletes the user's entry or raises `Ecto.NoResultsError`.

  Scoped by owner so another user's entry is indistinguishable from a
  missing one (404, never 403).
  """
  def delete_entry(user_id, id) do
    MealPlanEntry
    |> Repo.get_by!(id: id, user_id: user_id)
    |> Repo.delete()
  end

  @doc """
  Derives the grocery checklist for the week containing `week_start`, one
  group per planned recipe:

      [%{post: %{id: 1, caption: "...", thumbnail: "..." | nil},
         items: [%{item_key: "1:2", name: "...", quantity: "...",
                   unit: "...", checked: false}]}]

  Groups are ordered by post id, items by ingredient order then id. Posts
  planned on several days of the week appear once. Soft-deleted and
  moderator-removed posts never appear; posts without ingredients are
  omitted entirely. `checked` reflects the user's `grocery_checks` rows for
  the (Monday-normalized) week.
  """
  def grocery_list(user_id, %Date{} = week_start) do
    {monday, sunday} = week_window(week_start)
    checked_keys = checked_item_keys(user_id, monday)

    MealPlanEntry
    |> where([e], e.user_id == ^user_id)
    |> where([e], e.date >= ^monday and e.date <= ^sunday)
    |> join(:inner, [e], p in Post,
      on: e.post_id == p.id and is_nil(p.deleted_at) and is_nil(p.removed_at)
    )
    |> join(:inner, [e, p], i in Ingredient, on: i.post_id == p.id)
    |> join(:left, [e, p, i], ph in PostPhoto, on: ph.post_id == p.id and ph.position == 0)
    |> order_by([e, p, i], asc: p.id, asc: i.order, asc: i.id)
    |> select([e, p, i, ph], %{
      post_id: p.id,
      caption: p.caption,
      photo_url: ph.url,
      ingredient_id: i.id,
      name: i.name,
      quantity: i.quantity,
      unit: i.unit
    })
    |> Repo.all()
    # The same post planned on two days of the week joins its ingredients
    # once per entry — collapse to one row per (post, ingredient).
    |> Enum.uniq_by(&{&1.post_id, &1.ingredient_id})
    |> Enum.chunk_by(& &1.post_id)
    |> Enum.map(&grocery_group(&1, checked_keys))
  end

  @doc """
  Sets or clears a grocery check for the (Monday-normalized) week.

  Idempotent both ways: `checked: true` upserts (`on_conflict: :nothing` on
  the unique index), `checked: false` deletes whether or not a row exists.
  Returns `:ok`, or `{:error, %Ecto.Changeset{}}` when `item_key` is not a
  valid "post_id:ingredient_id" key.
  """
  def set_check(user_id, %Date{} = week_start, item_key, checked) when is_boolean(checked) do
    monday = Date.beginning_of_week(week_start)

    changeset =
      GroceryCheck.changeset(%GroceryCheck{}, %{
        user_id: user_id,
        week_start: monday,
        item_key: item_key
      })

    with {:ok, check} <- Ecto.Changeset.apply_action(changeset, :insert) do
      if checked do
        {:ok, _} =
          Repo.insert(changeset,
            on_conflict: :nothing,
            conflict_target: [:user_id, :week_start, :item_key]
          )
      else
        GroceryCheck
        |> where([gc], gc.user_id == ^user_id)
        |> where([gc], gc.week_start == ^monday and gc.item_key == ^check.item_key)
        |> Repo.delete_all()
      end

      :ok
    end
  end

  defp week_window(%Date{} = date) do
    monday = Date.beginning_of_week(date)
    {monday, Date.add(monday, 6)}
  end

  defp checked_item_keys(user_id, monday) do
    GroceryCheck
    |> where([gc], gc.user_id == ^user_id and gc.week_start == ^monday)
    |> select([gc], gc.item_key)
    |> Repo.all()
    |> MapSet.new()
  end

  defp grocery_group([first | _] = rows, checked_keys) do
    %{
      post: %{
        id: first.post_id,
        caption: first.caption,
        thumbnail: ImageProcessor.thumb_url(first.photo_url)
      },
      items: Enum.map(rows, &grocery_item(&1, checked_keys))
    }
  end

  defp grocery_item(row, checked_keys) do
    item_key = "#{row.post_id}:#{row.ingredient_id}"

    %{
      item_key: item_key,
      name: row.name,
      quantity: row.quantity,
      unit: row.unit,
      checked: MapSet.member?(checked_keys, item_key)
    }
  end
end
