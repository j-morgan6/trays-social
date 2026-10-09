defmodule TraysSocial.Posts.GroupedSearchTest do
  use TraysSocial.DataCase, async: true

  import Ecto.Query
  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.Posts
  alias TraysSocial.Posts.Bookmark
  alias TraysSocial.Posts.BrowseCategories
  alias TraysSocial.Repo

  setup do
    viewer = user_fixture()
    friend = user_fixture()
    stranger = user_fixture()
    {:ok, _} = Accounts.follow_user(viewer, friend)
    %{viewer: viewer, friend: friend, stranger: stranger, fids: [friend.id]}
  end

  defp search(group, opts \\ []) do
    "taco"
    |> Posts.search_posts(Keyword.merge([group: group, recipes_only: true], opts))
    |> Enum.map(& &1.id)
  end

  describe "search_posts/2 :group and :recipes_only" do
    test "each recipe lands in exactly one group", ctx do
      mine = post_fixture(%{user_id: ctx.viewer.id, caption: "fish taco"})
      saved_friend = post_fixture(%{user_id: ctx.friend.id, caption: "birria taco"})
      {:ok, _} = Posts.create_bookmark(ctx.viewer.id, saved_friend.id)
      friend = post_fixture(%{user_id: ctx.friend.id, caption: "taco salad"})
      other = post_fixture(%{user_id: ctx.stranger.id, caption: "al pastor taco"})

      assert {:tray, ctx.viewer.id} |> search() |> Enum.sort() ==
               Enum.sort([mine.id, saved_friend.id])

      assert search({:following, ctx.viewer.id, ctx.fids}) == [friend.id]
      assert search({:everyone, ctx.viewer.id, ctx.fids}) == [other.id]
    end

    test "a bookmarked friend recipe appears only in tray", ctx do
      saved = post_fixture(%{user_id: ctx.friend.id, caption: "taco"})
      {:ok, _} = Posts.create_bookmark(ctx.viewer.id, saved.id)

      assert search({:tray, ctx.viewer.id}) == [saved.id]
      assert search({:following, ctx.viewer.id, ctx.fids}) == []
      assert search({:everyone, ctx.viewer.id, ctx.fids}) == []
    end

    test "a bookmarked stranger recipe appears only in tray", ctx do
      saved = post_fixture(%{user_id: ctx.stranger.id, caption: "taco bowl"})
      {:ok, _} = Posts.create_bookmark(ctx.viewer.id, saved.id)

      assert search({:tray, ctx.viewer.id}) == [saved.id]
      assert search({:following, ctx.viewer.id, ctx.fids}) == []
      assert search({:everyone, ctx.viewer.id, ctx.fids}) == []
    end

    test "another user's bookmark does not pull a recipe into the viewer's tray", ctx do
      other = post_fixture(%{user_id: ctx.stranger.id, caption: "taco"})
      {:ok, _} = Posts.create_bookmark(ctx.friend.id, other.id)

      assert search({:tray, ctx.viewer.id}) == []
      assert search({:everyone, ctx.viewer.id, ctx.fids}) == [other.id]
    end

    test "recipes_only drops photo posts", ctx do
      post_fixture(%{user_id: ctx.stranger.id, caption: "taco night", type: "post"})
      assert search({:everyone, ctx.viewer.id, ctx.fids}) == []
    end

    test "an empty following list keeps everyone working", ctx do
      other = post_fixture(%{user_id: ctx.stranger.id, caption: "taco"})
      assert search({:following, ctx.viewer.id, []}) == []
      assert search({:everyone, ctx.viewer.id, []}) == [other.id]
    end

    test "without :group or :recipes_only the search is unchanged", ctx do
      photo = post_fixture(%{user_id: ctx.stranger.id, caption: "taco night", type: "post"})
      mine = post_fixture(%{user_id: ctx.viewer.id, caption: "taco"})

      ids = "taco" |> Posts.search_posts() |> Enum.map(& &1.id)
      assert Enum.sort(ids) == Enum.sort([photo.id, mine.id])
    end
  end

  describe "search_grouped/3" do
    test "returns disjoint recipe groups and skips blocked authors", ctx do
      mine = post_fixture(%{user_id: ctx.viewer.id, caption: "taco"})
      theirs = post_fixture(%{user_id: ctx.friend.id, caption: "taco"})
      other = post_fixture(%{user_id: ctx.stranger.id, caption: "taco"})
      blocked = user_fixture()
      post_fixture(%{user_id: blocked.id, caption: "taco"})
      post_fixture(%{user_id: ctx.stranger.id, caption: "taco night", type: "post"})

      result =
        Posts.search_grouped(ctx.viewer.id, "taco",
          following_ids: ctx.fids,
          blocked_user_ids: [blocked.id]
        )

      assert Enum.map(result.tray, & &1.id) == [mine.id]
      assert Enum.map(result.following, & &1.id) == [theirs.id]
      assert Enum.map(result.everyone, & &1.id) == [other.id]
    end

    test "previews are capped and everyone is paged", ctx do
      for _ <- 1..4, do: post_fixture(%{user_id: ctx.viewer.id, caption: "taco"})
      for _ <- 1..4, do: post_fixture(%{user_id: ctx.friend.id, caption: "taco"})
      for _ <- 1..4, do: post_fixture(%{user_id: ctx.stranger.id, caption: "taco"})

      result =
        Posts.search_grouped(ctx.viewer.id, "taco",
          following_ids: ctx.fids,
          preview_limit: 2,
          limit: 3
        )

      assert length(result.tray) == 2
      assert length(result.following) == 2
      assert length(result.everyone) == 3
    end
  end

  describe "list_most_saved_posts/2" do
    test "orders by saves this week, tops up with liked recipes, skips blocked", ctx do
      top = post_fixture(%{user_id: ctx.stranger.id})
      second = post_fixture(%{user_id: ctx.stranger.id})
      for u <- [user_fixture(), user_fixture()], do: Posts.create_bookmark(u.id, top.id)
      Posts.create_bookmark(user_fixture().id, second.id)

      liked = post_fixture(%{user_id: ctx.stranger.id})
      {:ok, _} = Posts.like_post(liked, user_fixture())

      stale = post_fixture(%{user_id: ctx.stranger.id})
      {:ok, b} = Posts.create_bookmark(user_fixture().id, stale.id)
      old = :second |> DateTime.utc_now() |> DateTime.add(-10, :day)

      Bookmark
      |> where([x], x.id == ^b.id)
      |> Repo.update_all(set: [inserted_at: old])

      blocked_author = user_fixture()
      hidden = post_fixture(%{user_id: blocked_author.id})
      Posts.create_bookmark(user_fixture().id, hidden.id)

      result =
        3
        |> Posts.list_most_saved_posts(blocked_user_ids: [blocked_author.id])
        |> Enum.map(& &1.id)

      assert result == [top.id, second.id, liked.id]
      refute stale.id in result
      refute hidden.id in result
    end

    test "never returns photo posts or blocked authors in the top-up", ctx do
      post_fixture(%{user_id: ctx.stranger.id, type: "post"})
      blocked_author = user_fixture()
      post_fixture(%{user_id: blocked_author.id})
      recipe = post_fixture(%{user_id: ctx.stranger.id})

      result =
        10
        |> Posts.list_most_saved_posts(blocked_user_ids: [blocked_author.id])
        |> Enum.map(& &1.id)

      assert result == [recipe.id]
    end
  end

  describe "BrowseCategories" do
    test "browse categories are fixed and fetchable" do
      assert Enum.map(BrowseCategories.list(), & &1.key) ==
               ~w(quick_dinners chicken pasta breakfast baking soups)

      assert %{max_cooking_time: 30} = BrowseCategories.fetch("quick_dinners")
      assert BrowseCategories.fetch("nope") == nil
      assert BrowseCategories.fetch(nil) == nil
    end
  end
end
