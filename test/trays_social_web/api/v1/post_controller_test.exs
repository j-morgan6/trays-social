defmodule TraysSocialWeb.API.V1.PostControllerTest do
  # async: false — the trending tests toggle the global :in_app_ads feature
  # flag via Application.put_env/3 (G38/W158); running serially keeps that
  # mutation from racing other tests that read :features.
  use TraysSocialWeb.ConnCase, async: false

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  setup :register_and_api_authenticate_user

  # Turn the :in_app_ads flag on for the duration of one test, restoring the
  # prior config on exit.
  defp enable_in_app_ads do
    original = Application.get_env(:trays_social, :features, [])
    Application.put_env(:trays_social, :features, Keyword.put(original, :in_app_ads, true))
    on_exit(fn -> Application.put_env(:trays_social, :features, original) end)
  end

  describe "GET /api/v1/posts/trending" do
    # Seed `count` posts with strictly descending like_count so the trending
    # order (like_count desc, inserted_at desc) is deterministic regardless of
    # second-precision timestamp ties. Returns post ids in expected trending
    # order.
    defp seed_trending_posts(user, count) do
      for i <- 0..(count - 1) do
        post = post_fixture(%{user_id: user.id})

        {:ok, updated} =
          post
          |> Ecto.Changeset.change(like_count: 1000 - i)
          |> TraysSocial.Repo.update()

        updated.id
      end
    end

    test "flag off (default): flat PostJSON list with ad_config disabled",
         %{conn: conn, user: user} do
      seed_trending_posts(user, 3)

      conn = get(conn, ~p"/api/v1/posts/trending")

      assert %{"data" => [item | _] = data, "ad_config" => ad_config} =
               json_response(conn, 200)

      assert ad_config["enabled"] == false
      assert ad_config["frequency"] == TraysSocial.Monetization.ad_frequency()

      # Flat shape: post fields at the top level, no union wrapper. An item's
      # "type" is the post's own content-type ("recipe"/"post"), never "ad".
      assert Map.has_key?(item, "id")
      assert Map.has_key?(item, "caption")
      refute Map.has_key?(item, "post")
      refute Map.has_key?(item, "ad")
      refute Enum.any?(data, &(&1["type"] == "ad"))
    end

    test "flag on: tagged union with ad slots at placement \"find\" and correct cadence",
         %{conn: conn, user: user} do
      freq = TraysSocial.Monetization.ad_frequency()
      seed_trending_posts(user, freq + 1)
      enable_in_app_ads()

      conn = get(conn, ~p"/api/v1/posts/trending")

      assert %{"data" => data, "ad_config" => %{"enabled" => true}} = json_response(conn, 200)

      assert Enum.all?(data, &(&1["type"] in ["post", "ad"]))

      # One ad after each full group of `freq` posts, never trailing: with
      # freq + 1 posts that is exactly one ad, sitting after the first group.
      assert Enum.map(data, & &1["type"]) ==
               List.duplicate("post", freq) ++ ["ad", "post"]

      [ad] = Enum.filter(data, &(&1["type"] == "ad"))
      assert %{"slot" => 0, "placement" => "find"} = ad["ad"]
    end

    test "organic integrity: union post order matches the flat order with no dup or drop",
         %{conn: conn, user: user} do
      freq = TraysSocial.Monetization.ad_frequency()
      expected_ids = seed_trending_posts(user, freq + 1)

      flat_ids =
        conn
        |> get(~p"/api/v1/posts/trending")
        |> json_response(200)
        |> Map.fetch!("data")
        |> Enum.map(& &1["id"])

      enable_in_app_ads()

      union_ids =
        conn
        |> get(~p"/api/v1/posts/trending")
        |> json_response(200)
        |> Map.fetch!("data")
        |> Enum.filter(&(&1["type"] == "post"))
        |> Enum.map(& &1["post"]["id"])

      assert flat_ids == expected_ids
      assert union_ids == expected_ids
    end

    test "subscribers keep the flat shape and disabled ad_config even with the flag on",
         %{conn: conn, user: user} do
      {:ok, _} = TraysSocial.Accounts.set_subscriber(user, true)
      enable_in_app_ads()
      seed_trending_posts(user, 3)

      conn = get(conn, ~p"/api/v1/posts/trending")

      assert %{"data" => [item | _], "ad_config" => %{"enabled" => false}} =
               json_response(conn, 200)

      assert Map.has_key?(item, "id")
      refute Map.has_key?(item, "post")
    end

    test "flag on with fewer than ad_frequency posts: union shape, zero ads",
         %{conn: conn, user: user} do
      seed_trending_posts(user, 3)
      enable_in_app_ads()

      conn = get(conn, ~p"/api/v1/posts/trending")

      assert %{"data" => data, "ad_config" => %{"enabled" => true}} = json_response(conn, 200)

      assert length(data) == 3
      assert Enum.all?(data, &(&1["type"] == "post"))
      assert Enum.all?(data, &Map.has_key?(&1, "post"))
    end
  end

  describe "GET /api/v1/posts/:id" do
    test "returns post with all associations", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})

      conn = get(conn, ~p"/api/v1/posts/#{post.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == post.id
      assert data["type"] == "recipe"
      assert is_list(data["ingredients"])
      assert is_list(data["cooking_steps"])
      assert data["user"]["id"] == user.id
    end

    # W167: direct post links are invisible across a block in either
    # direction — 404, not 403, so blocks aren't enumerable.
    test "returns 404 for a post whose author blocked the requester", %{conn: conn, user: user} do
      author = user_fixture()
      post = post_fixture(%{user_id: author.id})
      {:ok, _} = TraysSocial.Accounts.block_user(author.id, user.id)

      conn = get(conn, ~p"/api/v1/posts/#{post.id}")

      assert json_response(conn, 404)
    end

    test "returns 404 for nonexistent post", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/posts/999999")

      assert json_response(conn, 404)
    end

    test "returns 404 for deleted post", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})
      TraysSocial.Posts.delete_post(post)

      conn = get(conn, ~p"/api/v1/posts/#{post.id}")

      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/posts" do
    test "creates a recipe post", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/posts", %{
          photo_url: "/uploads/test.jpg",
          caption: "My recipe",
          cooking_time_minutes: 30,
          type: "recipe",
          ingredients: [%{name: "Salt", quantity: "1 tsp"}],
          cooking_steps: [%{description: "Mix it", order: 0}]
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert data["caption"] == "My recipe"
      assert data["type"] == "recipe"
    end

    test "creates a simple post", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/posts", %{
          photo_url: "/uploads/test.jpg",
          caption: "Just food",
          type: "post"
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert data["type"] == "post"
    end

    test "returns error for missing required fields", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/posts", %{caption: "no photo"})

      assert json_response(conn, 422)
    end
  end

  describe "DELETE /api/v1/posts/:id" do
    test "soft-deletes own post", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})

      conn = delete(conn, ~p"/api/v1/posts/#{post.id}")

      assert %{"data" => %{"message" => "post deleted"}} = json_response(conn, 200)
    end

    test "returns 403 for other user's post", %{conn: conn} do
      other_user = user_fixture()
      post = post_fixture(%{user_id: other_user.id})

      conn = delete(conn, ~p"/api/v1/posts/#{post.id}")

      assert json_response(conn, 403)
    end

    test "returns 404 for nonexistent post", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/posts/999999")

      assert json_response(conn, 404)
    end
  end

  describe "PATCH /api/v1/posts/:id" do
    test "owner can update caption, cooking time, servings, and photo", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})

      conn =
        patch(conn, ~p"/api/v1/posts/#{post.id}", %{
          caption: "Updated caption",
          cooking_time_minutes: 99,
          servings: 6,
          photo_url: "https://images.unsplash.com/photo-updated?w=800"
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == post.id
      assert data["caption"] == "Updated caption"
      assert data["cooking_time_minutes"] == 99
      assert data["servings"] == 6
      assert [%{"url" => "https://images.unsplash.com/photo-updated?w=800"}] = data["photos"]
    end

    test "a partial update leaves omitted fields (and the required photo_url) intact",
         %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})

      conn = patch(conn, ~p"/api/v1/posts/#{post.id}", %{caption: "Just the caption"})

      assert %{"data" => data} = json_response(conn, 200)
      assert data["caption"] == "Just the caption"
      assert data["cooking_time_minutes"] == 42
    end

    test "ownership and type are immutable — user_id/type in the body are ignored",
         %{conn: conn, user: user} do
      other_user = user_fixture()
      post = post_fixture(%{user_id: user.id})

      conn =
        patch(conn, ~p"/api/v1/posts/#{post.id}", %{
          caption: "Still mine",
          user_id: other_user.id,
          type: "tip"
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["user"]["id"] == user.id
      assert data["type"] == "recipe"
    end

    test "returns 403 for another user's post", %{conn: conn} do
      other_user = user_fixture()
      post = post_fixture(%{user_id: other_user.id})

      conn = patch(conn, ~p"/api/v1/posts/#{post.id}", %{caption: "hijack"})

      assert json_response(conn, 403)
    end

    test "returns 404 for a nonexistent post", %{conn: conn} do
      conn = patch(conn, ~p"/api/v1/posts/999999", %{caption: "ghost"})

      assert json_response(conn, 404)
    end

    test "returns 404 for a soft-deleted post", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})
      {:ok, _} = TraysSocial.Posts.delete_post(post)

      conn = patch(conn, ~p"/api/v1/posts/#{post.id}", %{caption: "back from the dead"})

      assert json_response(conn, 404)
    end

    test "returns 422 for invalid attrs", %{conn: conn, user: user} do
      post = post_fixture(%{user_id: user.id})

      conn =
        patch(conn, ~p"/api/v1/posts/#{post.id}", %{caption: String.duplicate("x", 501)})

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Enum.any?(errors, &(&1["field"] == "caption"))
    end
  end
end
