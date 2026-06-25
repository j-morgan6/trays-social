defmodule TraysSocialWeb.API.V1.JSON.FeedItemJSONTest do
  use TraysSocial.DataCase, async: true

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Repo
  alias TraysSocialWeb.API.V1.JSON.FeedItemJSON
  alias TraysSocialWeb.API.V1.JSON.PostJSON

  defp loaded_post(user) do
    post_fixture(%{user_id: user.id})
    |> Repo.preload([:user, :post_photos, :ingredients, :cooking_steps, :tools, :post_tags])
  end

  describe "render_post/2" do
    test "wraps a post as a tagged union item with the full PostJSON payload" do
      user = user_fixture()
      post = loaded_post(user)

      item = FeedItemJSON.render_post(post)

      assert item.type == "post"
      # The nested payload is exactly PostJSON.render/2 — every post field is retained.
      assert item.post == PostJSON.render(post)
      assert item.post.id == post.id
      # The post's own content-type ("recipe"/"post") survives untouched, distinct
      # from the union discriminator above it.
      assert item.post.type == post.type
    end

    test "passes liked/bookmarked opts through to PostJSON" do
      user = user_fixture()
      post = loaded_post(user)
      opts = %{liked_post_ids: MapSet.new([post.id]), bookmarked_post_ids: MapSet.new()}

      item = FeedItemJSON.render_post(post, opts)

      assert item.post.liked_by_current_user == true
      assert item.post.bookmarked_by_current_user == false
    end
  end

  describe "render_list/2" do
    test "wraps every post and preserves order" do
      user = user_fixture()
      posts = [loaded_post(user), loaded_post(user)]

      items = FeedItemJSON.render_list(posts)

      assert length(items) == 2
      assert Enum.all?(items, &(&1.type == "post"))
      assert Enum.map(items, & &1.post.id) == Enum.map(posts, & &1.id)
    end

    test "returns an empty list for no posts" do
      assert FeedItemJSON.render_list([]) == []
    end
  end

  describe "render_ad/1" do
    test "wraps an ad payload as a tagged ad item" do
      ad = %{headline: "Sponsored", destination_url: "https://example.com"}

      assert FeedItemJSON.render_ad(ad) == %{type: "ad", ad: ad}
    end
  end

  describe "interleave_ads/2 (G38/W163)" do
    # Opaque post items — interleave_ads doesn't inspect post contents, so tiny
    # stand-ins keep the density assertions readable.
    defp post_items(n), do: for(i <- 1..n, do: %{type: "post", post: %{id: i}})

    defp types(items), do: Enum.map(items, & &1.type)

    test "inserts no ad when there are fewer than freq posts (short page)" do
      items = post_items(1)
      assert FeedItemJSON.interleave_ads(items, 2) == items
    end

    test "inserts no ad when the page ends exactly on a group boundary (no trailing ad)" do
      items = post_items(2)
      assert FeedItemJSON.interleave_ads(items, 2) == items

      four = post_items(4)
      # 4 posts / freq 2 = exactly two full groups -> still no trailing ad.
      assert types(FeedItemJSON.interleave_ads(four, 2)) == ["post", "post", "ad", "post", "post"]
    end

    test "inserts one ad after the first freq posts when the page spills over" do
      result = FeedItemJSON.interleave_ads(post_items(3), 2)

      assert types(result) == ["post", "post", "ad", "post"]
      ad = Enum.at(result, 2)
      assert ad == %{type: "ad", ad: %{slot: 0, placement: "feed"}}
    end

    test "inserts multiple ads with incrementing slot indices, none trailing" do
      result = FeedItemJSON.interleave_ads(post_items(5), 2)

      assert types(result) == ["post", "post", "ad", "post", "post", "ad", "post"]
      assert Enum.at(result, 2).ad.slot == 0
      assert Enum.at(result, 5).ad.slot == 1
      # last element is a post, never an ad
      assert List.last(result).type == "post"
    end

    test "empty list stays empty" do
      assert FeedItemJSON.interleave_ads([], 8) == []
    end
  end
end
