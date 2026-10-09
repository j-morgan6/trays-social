defmodule TraysSocial.HomeTest do
  use TraysSocial.DataCase, async: true

  import Ecto.Query
  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.Follow
  alias TraysSocial.Home
  alias TraysSocial.MealPlans
  alias TraysSocial.Posts
  alias TraysSocial.Posts.Post
  alias TraysSocial.Posts.RecipeOpen
  alias TraysSocial.Repo

  defp days_ago(days) do
    :second |> DateTime.utc_now() |> DateTime.add(-days, :day)
  end

  defp backdate(post, days) do
    query = where(Post, [p], p.id == ^post.id)
    {1, _} = Repo.update_all(query, set: [inserted_at: days_ago(days)])
    post
  end

  defp opened(user, post, days) do
    Repo.insert!(%RecipeOpen{user_id: user.id, post_id: post.id, last_opened_at: days_ago(days)})
  end

  # block_user/2 deletes follows in both directions and follow_user/2 refuses a
  # blocked pair, so a follow that outlives a block has to be written directly.
  defp refollow(follower, followed) do
    Repo.insert!(%Follow{follower_id: follower.id, followed_id: followed.id})
  end

  defp ids(posts), do: Enum.map(posts, & &1.id)
  defp user_ids(rows), do: Enum.map(rows, & &1.user.id)

  setup do
    %{viewer: user_fixture(), friend: user_fixture(), stranger: user_fixture()}
  end

  describe "jump_back_in" do
    test "orders tray recipes by most recent open, then newest", ctx do
      a = post_fixture(%{user_id: ctx.viewer.id})
      b = post_fixture(%{user_id: ctx.viewer.id})
      saved = post_fixture(%{user_id: ctx.stranger.id})
      {:ok, _} = Posts.create_bookmark(ctx.viewer.id, saved.id)
      _not_in_tray = post_fixture(%{user_id: ctx.stranger.id})
      opened(ctx.viewer, a, 1)
      opened(ctx.viewer, saved, 0)

      assert ids(Home.build(ctx.viewer).jump_back_in) == [saved.id, a.id, b.id]
    end

    test "caps at 6 and skips photo-only posts", ctx do
      for _ <- 1..7, do: post_fixture(%{user_id: ctx.viewer.id})
      photo = post_fixture(%{user_id: ctx.viewer.id, type: "post"})

      result = Home.build(ctx.viewer).jump_back_in
      assert length(result) == 6
      refute photo.id in ids(result)
    end

    test "is empty for an empty tray", ctx do
      _not_in_tray = post_fixture(%{user_id: ctx.stranger.id})
      assert Home.build(ctx.viewer).jump_back_in == []
    end

    test "skips deleted, removed and blocked-author recipes", ctx do
      kept = post_fixture(%{user_id: ctx.viewer.id})

      deleted = post_fixture(%{user_id: ctx.viewer.id})
      {:ok, _} = Posts.delete_post(deleted)

      removed = post_fixture(%{user_id: ctx.stranger.id})
      {:ok, _} = Posts.create_bookmark(ctx.viewer.id, removed.id)
      {:ok, _} = Posts.remove_post(removed, %{removed_by_id: ctx.friend.id, reason: "spam"})

      blocker = user_fixture()
      by_blocker = post_fixture(%{user_id: blocker.id})
      {:ok, _} = Posts.create_bookmark(ctx.viewer.id, by_blocker.id)
      {:ok, _} = Accounts.block_user(blocker.id, ctx.viewer.id)

      blocked = user_fixture()
      by_blocked = post_fixture(%{user_id: blocked.id})
      {:ok, _} = Posts.create_bookmark(ctx.viewer.id, by_blocked.id)
      {:ok, _} = Accounts.block_user(ctx.viewer.id, blocked.id)

      assert ids(Home.build(ctx.viewer).jump_back_in) == [kept.id]
    end
  end

  describe "tonight" do
    test "uses the given local date, not the server clock", ctx do
      post = post_fixture(%{user_id: ctx.viewer.id})
      local_today = Date.add(Date.utc_today(), 1)
      {:ok, entry} = MealPlans.create_entry(ctx.viewer, local_today, post)

      assert Home.build(ctx.viewer, today: local_today).tonight.id == entry.id
      assert Home.build(ctx.viewer, today: Date.utc_today()).tonight == nil
    end

    test "skips a blocked author's entry and a photo-only entry for the day", ctx do
      today = Date.utc_today()

      saved = post_fixture(%{user_id: ctx.stranger.id})
      {:ok, _} = Posts.create_bookmark(ctx.viewer.id, saved.id)
      {:ok, _} = MealPlans.create_entry(ctx.viewer, today, saved)
      {:ok, _} = Accounts.block_user(ctx.stranger.id, ctx.viewer.id)

      photo = post_fixture(%{user_id: ctx.viewer.id, type: "post"})
      {:ok, _} = MealPlans.create_entry(ctx.viewer, today, photo)

      # Planned last, so it only wins if the two earlier entries are skipped.
      mine = post_fixture(%{user_id: ctx.viewer.id})
      {:ok, kept} = MealPlans.create_entry(ctx.viewer, today, mine)

      assert Home.build(ctx.viewer, today: today).tonight.id == kept.id
    end
  end

  describe "friends_trays and new_from_following" do
    setup ctx do
      {:ok, _} = Accounts.follow_user(ctx.viewer, ctx.friend)
      quiet = user_fixture()
      {:ok, _} = Accounts.follow_user(ctx.viewer, quiet)
      Map.put(ctx, :quiet, quiet)
    end

    test "friends ordered by latest recipe, quiet follows last", ctx do
      post_fixture(%{user_id: ctx.friend.id})

      assert [%{user: first} = top, %{user: second} = bottom] =
               Home.build(ctx.viewer).friends_trays

      assert first.id == ctx.friend.id
      assert second.id == ctx.quiet.id
      assert %DateTime{} = top.last_posted_at
      assert bottom.last_posted_at == nil
    end

    test "friends_trays caps at 10", ctx do
      for _ <- 1..9, do: {:ok, _} = Accounts.follow_user(ctx.viewer, user_fixture())

      assert length(Home.build(ctx.viewer).friends_trays) == 10
    end

    test "new_from_following keeps the last 7 days, newest first", ctx do
      old = %{user_id: ctx.friend.id} |> post_fixture() |> backdate(8)
      older = %{user_id: ctx.friend.id} |> post_fixture() |> backdate(2)
      newer = post_fixture(%{user_id: ctx.friend.id})
      photo = post_fixture(%{user_id: ctx.friend.id, type: "post"})
      deleted = post_fixture(%{user_id: ctx.friend.id})
      {:ok, _} = Posts.delete_post(deleted)
      _stranger = post_fixture(%{user_id: ctx.stranger.id})

      result = ids(Home.build(ctx.viewer).new_from_following)
      assert result == [newer.id, older.id]
      refute old.id in result
      refute photo.id in result
      refute deleted.id in result
    end

    test "new_from_following caps at 20", ctx do
      for _ <- 1..21, do: post_fixture(%{user_id: ctx.friend.id})
      assert length(Home.build(ctx.viewer).new_from_following) == 20
    end

    test "a followed user who blocked the viewer disappears from both", ctx do
      post_fixture(%{user_id: ctx.friend.id})
      {:ok, _} = Accounts.block_user(ctx.friend.id, ctx.viewer.id)
      refollow(ctx.viewer, ctx.friend)

      home = Home.build(ctx.viewer)
      refute ctx.friend.id in user_ids(home.friends_trays)
      assert ctx.quiet.id in user_ids(home.friends_trays)
      assert home.new_from_following == []
    end

    test "a followed user the viewer blocked disappears from both", ctx do
      post_fixture(%{user_id: ctx.friend.id})
      {:ok, _} = Accounts.block_user(ctx.viewer.id, ctx.friend.id)
      refollow(ctx.viewer, ctx.friend)

      home = Home.build(ctx.viewer)
      refute ctx.friend.id in user_ids(home.friends_trays)
      assert ctx.quiet.id in user_ids(home.friends_trays)
      assert home.new_from_following == []
    end

    test "no suggested cooks once the viewer follows someone", ctx do
      post_fixture(%{user_id: ctx.stranger.id})
      assert Home.build(ctx.viewer).suggested_cooks == []
    end
  end

  describe "suggested_cooks" do
    test "most recipes in 30 days, excluding self, blocked, and suspended", ctx do
      busy = user_fixture()
      for _ <- 1..3, do: post_fixture(%{user_id: busy.id})
      post_fixture(%{user_id: ctx.stranger.id})
      for _ <- 1..5, do: post_fixture(%{user_id: ctx.viewer.id})

      stale = user_fixture()
      for _ <- 1..4, do: %{user_id: stale.id} |> post_fixture() |> backdate(31)

      blocked = user_fixture()
      for _ <- 1..4, do: post_fixture(%{user_id: blocked.id})
      {:ok, _} = Accounts.block_user(ctx.viewer.id, blocked.id)

      blocker = user_fixture()
      for _ <- 1..4, do: post_fixture(%{user_id: blocker.id})
      {:ok, _} = Accounts.block_user(blocker.id, ctx.viewer.id)

      suspended = suspended_user_fixture()
      for _ <- 1..4, do: post_fixture(%{user_id: suspended.id})

      photo_cook = user_fixture()
      for _ <- 1..4, do: post_fixture(%{user_id: photo_cook.id, type: "post"})

      cooks = Home.build(ctx.viewer).suggested_cooks
      assert user_ids(cooks) == [busy.id, ctx.stranger.id]
      assert hd(cooks).recipe_count == 3
    end

    test "caps suggested cooks at 5", ctx do
      for _ <- 1..6, do: post_fixture(%{user_id: user_fixture().id})

      assert length(Home.build(ctx.viewer).suggested_cooks) == 5
    end
  end
end
