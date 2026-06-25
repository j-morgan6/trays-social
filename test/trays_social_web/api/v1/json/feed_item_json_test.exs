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

  describe "render_ad/1 (stub for W163)" do
    test "wraps an ad payload as a tagged ad item" do
      ad = %{headline: "Sponsored", destination_url: "https://example.com"}

      assert FeedItemJSON.render_ad(ad) == %{type: "ad", ad: ad}
    end
  end
end
