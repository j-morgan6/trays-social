defmodule TraysSocial.Posts.IngredientSearchTest do
  use TraysSocial.DataCase, async: true

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.Posts
  alias TraysSocial.Posts.Ingredient
  alias TraysSocial.Posts.IngredientSearch

  defp recipe(user, names) do
    ingredients = Enum.map(names, &%{name: &1, quantity: "1", unit: ""})
    post_fixture(%{user_id: user.id, ingredients: ingredients})
  end

  defp search(viewer, terms, opts \\ []) do
    following_ids = Accounts.list_following_ids(viewer.id)

    Posts.search_by_ingredients(
      viewer.id,
      terms,
      Keyword.merge([following_ids: following_ids, blocked_user_ids: []], opts)
    )
  end

  describe "normalize_terms/1" do
    test "lowercases, trims, singularizes, and dedupes" do
      assert {:ok, ["egg", "tomato", "rice"]} =
               IngredientSearch.normalize_terms(["Eggs", "  tomatoes ", "rice", "egg"])
    end

    test "keeps double-s words" do
      assert {:ok, ["swiss chard", "swiss", "molasse"]} =
               IngredientSearch.normalize_terms(["Swiss  chard", "Swiss", "molasses"])
    end

    test "rejects empty, too many, too long, and non-list input" do
      too_many = Enum.map(1..11, &"item#{&1}")
      too_long = [String.duplicate("a", 51)]

      assert {:error, :invalid_ingredients} = IngredientSearch.normalize_terms([])
      assert {:error, :invalid_ingredients} = IngredientSearch.normalize_terms(["  "])
      assert {:error, :invalid_ingredients} = IngredientSearch.normalize_terms(too_many)
      assert {:error, :invalid_ingredients} = IngredientSearch.normalize_terms(too_long)
      assert {:error, :invalid_ingredients} = IngredientSearch.normalize_terms("chicken")
      assert {:error, :invalid_ingredients} = IngredientSearch.normalize_terms(nil)
    end

    test "rejects NUL bytes, other control characters, and invalid UTF-8" do
      assert {:error, :invalid_ingredients} = IngredientSearch.normalize_terms(["chick\0en"])
      assert {:error, :invalid_ingredients} = IngredientSearch.normalize_terms(["rice\e"])

      assert {:error, :invalid_ingredients} =
               IngredientSearch.normalize_terms([<<"chick", 0xFF>>])
    end

    test "still accepts tabs and newlines, which collapse to spaces" do
      assert {:ok, ["soy sauce"]} = IngredientSearch.normalize_terms(["soy\tsauce\n"])
    end
  end

  describe "basic?/1" do
    test "matches exact normalized names only" do
      assert IngredientSearch.basic?("  Olive   OIL ")
      refute IngredientSearch.basic?("bell pepper")
      refute IngredientSearch.basic?("pepper flakes")
    end
  end

  describe "classify/2" do
    test "ignores pantry basics on the recipe side" do
      assert {:ok, []} =
               IngredientSearch.classify(["Chicken", "Kosher salt", "olive oil"], ["chicken"])
    end

    test "lists missing non-basic ingredients in recipe order" do
      names = ["chicken", "soy sauce", "bay leaf", "water"]
      assert {:ok, ["soy sauce", "bay leaf"]} = IngredientSearch.classify(names, ["chicken"])
    end

    test "matches quantities and adjectives inside the ingredient name" do
      assert {:ok, []} =
               IngredientSearch.classify(["2 boneless chicken thighs, skinless"], ["chicken"])
    end

    test "returns :no_match when nothing non-basic matches" do
      assert :no_match = IngredientSearch.classify(["beef", "salt"], ["salt"])
    end
  end

  describe "like_patterns/1" do
    test "escapes LIKE metacharacters" do
      assert IngredientSearch.like_patterns(["50%", "a_b", "x\\y"]) ==
               ["%50\\%%", "%a\\_b%", "%x\\\\y%"]
    end
  end

  describe "search/3" do
    setup do
      viewer = user_fixture()
      friend = user_fixture()
      stranger = user_fixture()
      {:ok, _} = Accounts.follow_user(viewer, friend)
      %{viewer: viewer, friend: friend, stranger: stranger}
    end

    test "splits everything and almost, drops 4+ missing", ctx do
      mine = recipe(ctx.viewer, ["chicken", "rice", "salt"])
      friends = recipe(ctx.friend, ["chicken", "soy sauce", "bay leaf"])
      _too_far = recipe(ctx.stranger, ["chicken", "a1", "b1", "c1", "d1"])

      result = search(ctx.viewer, ["chicken", "rice"])

      assert [%{post: %{id: mine_id}, missing: [], scope: :mine}] = result.everything
      assert mine_id == mine.id

      assert [%{post: %{id: friend_id}, missing: ["soy sauce", "bay leaf"], scope: :following}] =
               result.almost

      assert friend_id == friends.id
    end

    test "tie-break at equal missing count: mine, following, everyone", ctx do
      mine = recipe(ctx.viewer, ["chicken", "lime"])
      following = recipe(ctx.friend, ["chicken", "lime"])
      everyone = recipe(ctx.stranger, ["chicken", "lime"])

      assert [
               %{post: %{id: mine_id}, missing: ["lime"], scope: :mine},
               %{post: %{id: following_id}, missing: ["lime"], scope: :following},
               %{post: %{id: everyone_id}, missing: ["lime"], scope: :everyone}
             ] = search(ctx.viewer, ["chicken"]).almost

      assert [mine_id, following_id, everyone_id] == [mine.id, following.id, everyone.id]
    end

    test "keeps newest first at equal missing count and scope", ctx do
      older = recipe(ctx.stranger, ["chicken"])
      newer = recipe(ctx.stranger, ["chicken"])

      ids = Enum.map(search(ctx.viewer, ["chicken"]).everything, & &1.post.id)
      assert ids == [newer.id, older.id]
    end

    test "only ranks the newest candidates inside the candidate window", ctx do
      oldest = recipe(ctx.viewer, ["chicken"])
      recipe(ctx.stranger, ["chicken"])
      recipe(ctx.stranger, ["chicken"])

      ids =
        ctx.viewer
        |> search(["chicken"], candidate_limit: 2)
        |> Map.fetch!(:everything)
        |> Enum.map(& &1.post.id)

      assert length(ids) == 2
      refute oldest.id in ids
    end

    test "accepts mixed-case terms passed straight to search", ctx do
      recipe(ctx.stranger, ["chicken"])
      assert [%{missing: []}] = search(ctx.viewer, ["Chicken"]).everything
    end

    test "a bookmarked recipe counts as mine", ctx do
      saved = recipe(ctx.stranger, ["chicken"])
      {:ok, _} = Posts.create_bookmark(ctx.viewer.id, saved.id)

      assert [%{scope: :mine}] = search(ctx.viewer, ["chicken"]).everything
    end

    test "excludes blocked users, deleted posts, and photo-only posts", ctx do
      blocker = user_fixture()
      recipe(blocker, ["chicken"])
      {:ok, _} = Accounts.block_user(blocker.id, ctx.viewer.id)

      deleted = recipe(ctx.stranger, ["chicken"])
      {:ok, _} = Posts.delete_post(deleted)

      removed = recipe(ctx.stranger, ["chicken"])
      {:ok, _} = Posts.remove_post(removed, %{removed_by_id: ctx.viewer.id, reason: "spam"})

      photo = post_fixture(%{user_id: ctx.stranger.id, type: "post"})
      Repo.insert!(%Ingredient{post_id: photo.id, name: "chicken", order: 0})

      result = search(ctx.viewer, ["chicken"], blocked_user_ids: [blocker.id])
      assert result.everything == []
      assert result.almost == []
    end

    test "requires blocked_user_ids so a caller cannot skip block filtering", ctx do
      assert_raise KeyError, fn ->
        Posts.search_by_ingredients(ctx.viewer.id, ["chicken"], following_ids: [])
      end
    end

    test "treats LIKE metacharacters literally", ctx do
      recipe(ctx.stranger, ["50% dark chocolate"])
      recipe(ctx.stranger, ["500g flour"])

      assert [%{missing: []}] = search(ctx.viewer, ["50%"]).everything
    end

    test "caps results at 50", ctx do
      for _ <- 1..55, do: recipe(ctx.stranger, ["chicken"])

      result = search(ctx.viewer, ["chicken"])
      assert length(result.everything) + length(result.almost) == 50
    end
  end
end
