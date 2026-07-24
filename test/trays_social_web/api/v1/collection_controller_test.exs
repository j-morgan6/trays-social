defmodule TraysSocialWeb.API.V1.CollectionControllerTest do
  # async: false — these tests toggle the global :paid_tier feature flag via
  # Application.put_env/3 (G38/W172); running serially keeps that mutation
  # from racing other tests that read :features.
  use TraysSocialWeb.ConnCase, async: false

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.Collections
  alias TraysSocial.Posts

  setup :register_and_api_authenticate_user

  # Turn the :paid_tier flag on for the duration of one test, restoring the
  # prior config on exit.
  defp enable_paid_tier do
    original = Application.get_env(:trays_social, :features, [])
    Application.put_env(:trays_social, :features, Keyword.put(original, :paid_tier, true))
    on_exit(fn -> Application.put_env(:trays_social, :features, original) end)
  end

  defp subscribe(user) do
    {:ok, user} = Accounts.set_subscriber(user, true)
    user
  end

  defp collection_fixture(user, attrs \\ %{}) do
    {:ok, collection} =
      Collections.create_collection(user.id, Enum.into(attrs, %{name: "Weeknight dinners"}))

    collection
  end

  defp bookmarked_post_fixture(user, author, attrs \\ %{}) do
    post = post_fixture(Map.put(attrs, :user_id, author.id))
    {:ok, _} = Posts.create_bookmark(user.id, post.id)
    post
  end

  describe "full subscriber flow" do
    test "create, add, list, show, remove, delete", %{conn: conn, user: user} do
      enable_paid_tier()
      subscribe(user)
      author = user_fixture()

      post_a = bookmarked_post_fixture(user, author)

      post_b =
        bookmarked_post_fixture(user, author, %{
          post_photos: [%{url: "/uploads/cover.jpg", position: 0}]
        })

      # Create
      create_conn = post(conn, ~p"/api/v1/collections", %{"name" => "Desserts"})
      assert %{"data" => %{"id" => id, "name" => "Desserts"}} = json_response(create_conn, 201)

      # Add both posts (post_b last, so it supplies the cover)
      for post <- [post_a, post_b] do
        add_conn = post(conn, ~p"/api/v1/collections/#{id}/posts/#{post.id}")
        assert %{"data" => %{"message" => "added to collection"}} = json_response(add_conn, 201)
      end

      # List: item_count and cover photo
      index_conn = get(conn, ~p"/api/v1/collections")

      assert %{
               "data" => [
                 %{
                   "id" => ^id,
                   "name" => "Desserts",
                   "item_count" => 2,
                   "cover_photo_url" => "/uploads/cover.jpg"
                 }
               ]
             } = json_response(index_conn, 200)

      # Show: newest item first, cursor round-trips to the next (empty) page
      show_conn = get(conn, ~p"/api/v1/collections/#{id}")
      assert %{"data" => [first, second], "cursor" => cursor} = json_response(show_conn, 200)
      assert first["id"] == post_b.id
      assert second["id"] == post_a.id
      assert is_binary(cursor)

      next_conn = get(conn, ~p"/api/v1/collections/#{id}?cursor=#{cursor}")
      assert %{"data" => [], "cursor" => nil} = json_response(next_conn, 200)

      # Remove one post
      remove_conn = delete(conn, ~p"/api/v1/collections/#{id}/posts/#{post_b.id}")

      assert %{"data" => %{"message" => "removed from collection"}} =
               json_response(remove_conn, 200)

      assert [%{"item_count" => 1}] =
               json_response(get(conn, ~p"/api/v1/collections"), 200)["data"]

      # Delete the collection
      delete_conn = delete(conn, ~p"/api/v1/collections/#{id}")
      assert %{"data" => %{"message" => "collection deleted"}} = json_response(delete_conn, 200)
      assert %{"data" => []} = json_response(get(conn, ~p"/api/v1/collections"), 200)

      # Bookmarks and posts survive the collection delete
      assert Posts.bookmarked?(user.id, post_a.id)
      assert Posts.get_post!(post_b.id).id == post_b.id
    end
  end

  describe "subscription gating" do
    test "non-subscriber with flag on gets 403 subscription_required on gated writes",
         %{conn: conn, user: user} do
      enable_paid_tier()
      collection = collection_fixture(user)
      post_record = post_fixture(%{user_id: user.id})

      gated = [
        post(conn, ~p"/api/v1/collections", %{"name" => "Blocked"}),
        patch(conn, ~p"/api/v1/collections/#{collection.id}", %{"name" => "Renamed"}),
        post(conn, ~p"/api/v1/collections/#{collection.id}/posts/#{post_record.id}")
      ]

      for gated_conn <- gated do
        assert %{"errors" => [%{"code" => "subscription_required", "message" => message}]} =
                 json_response(gated_conn, 403)

        assert message == "Trays Plus subscription required"
      end
    end

    test "subscriber with flag off gets 403 subscription_required on gated writes",
         %{conn: conn, user: user} do
      subscribe(user)
      collection = collection_fixture(user)
      post_record = post_fixture(%{user_id: user.id})

      gated = [
        post(conn, ~p"/api/v1/collections", %{"name" => "Blocked"}),
        patch(conn, ~p"/api/v1/collections/#{collection.id}", %{"name" => "Renamed"}),
        post(conn, ~p"/api/v1/collections/#{collection.id}/posts/#{post_record.id}")
      ]

      for gated_conn <- gated do
        assert %{"errors" => [%{"code" => "subscription_required"}]} =
                 json_response(gated_conn, 403)
      end
    end

    test "non-subscriber can still read, delete a collection, and remove items",
         %{conn: conn, user: user} do
      # Graceful re-lock: the collection was built while subscribed; the lapsed
      # user keeps read and delete access to their own data.
      collection = collection_fixture(user)
      post_record = post_fixture(%{user_id: user.id})
      {:ok, _} = Collections.add_post(user, collection, post_record)

      assert %{"data" => [%{"item_count" => 1}]} =
               json_response(get(conn, ~p"/api/v1/collections"), 200)

      assert %{"data" => [_]} =
               json_response(get(conn, ~p"/api/v1/collections/#{collection.id}"), 200)

      remove_conn = delete(conn, ~p"/api/v1/collections/#{collection.id}/posts/#{post_record.id}")

      assert %{"data" => %{"message" => "removed from collection"}} =
               json_response(remove_conn, 200)

      delete_conn = delete(conn, ~p"/api/v1/collections/#{collection.id}")
      assert %{"data" => %{"message" => "collection deleted"}} = json_response(delete_conn, 200)
    end
  end

  describe "POST /api/v1/collections validation" do
    setup %{user: user} do
      enable_paid_tier()
      subscribe(user)
      :ok
    end

    test "duplicate name returns a changeset error", %{conn: conn, user: user} do
      collection_fixture(user, %{name: "Desserts"})

      conn = post(conn, ~p"/api/v1/collections", %{"name" => "Desserts"})

      assert %{"errors" => [%{"field" => "name", "message" => "has already been taken"}]} =
               json_response(conn, 422)
    end

    test "missing name returns a changeset error", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/collections", %{})

      assert %{"errors" => [%{"field" => "name", "message" => "can't be blank"}]} =
               json_response(conn, 422)
    end

    test "name over 60 characters returns a changeset error", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/collections", %{"name" => String.duplicate("a", 61)})

      assert %{"errors" => [%{"field" => "name", "message" => message}]} =
               json_response(conn, 422)

      assert message =~ "at most 60"
    end
  end

  describe "add post eligibility and ownership" do
    setup %{user: user} do
      enable_paid_tier()
      subscribe(user)
      :ok
    end

    test "adding a post the user neither bookmarked nor authored returns 403",
         %{conn: conn, user: user} do
      author = user_fixture()
      collection = collection_fixture(user)
      post_record = post_fixture(%{user_id: author.id})

      conn = post(conn, ~p"/api/v1/collections/#{collection.id}/posts/#{post_record.id}")

      assert %{"errors" => [%{"message" => "forbidden"}]} = json_response(conn, 403)
    end

    test "adding an unknown post returns 404", %{conn: conn, user: user} do
      collection = collection_fixture(user)

      conn = post(conn, ~p"/api/v1/collections/#{collection.id}/posts/0")

      assert %{"errors" => [%{"message" => "not found"}]} = json_response(conn, 404)
    end

    test "adding a soft-deleted post returns 404", %{conn: conn, user: user} do
      collection = collection_fixture(user)
      post_record = post_fixture(%{user_id: user.id})
      {:ok, _} = Posts.delete_post(post_record)

      conn = post(conn, ~p"/api/v1/collections/#{collection.id}/posts/#{post_record.id}")

      assert json_response(conn, 404)
    end

    test "another user's collection is a 404 on every route", %{conn: conn, user: user} do
      other = user_fixture()
      collection = collection_fixture(other)
      post_record = post_fixture(%{user_id: user.id})

      requests = [
        get(conn, ~p"/api/v1/collections/#{collection.id}"),
        patch(conn, ~p"/api/v1/collections/#{collection.id}", %{"name" => "Hijack"}),
        delete(conn, ~p"/api/v1/collections/#{collection.id}"),
        post(conn, ~p"/api/v1/collections/#{collection.id}/posts/#{post_record.id}"),
        delete(conn, ~p"/api/v1/collections/#{collection.id}/posts/#{post_record.id}")
      ]

      for request_conn <- requests do
        assert %{"errors" => [%{"message" => "not found"}]} = json_response(request_conn, 404)
      end
    end

    test "non-numeric collection id returns 404", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/collections/abc")

      assert json_response(conn, 404)
    end
  end

  describe "GET /api/v1/collections/:id" do
    test "excludes deleted posts", %{conn: conn, user: user} do
      collection = collection_fixture(user)
      kept = post_fixture(%{user_id: user.id})
      deleted = post_fixture(%{user_id: user.id})

      {:ok, _} = Collections.add_post(user, collection, kept)
      {:ok, _} = Collections.add_post(user, collection, deleted)
      {:ok, _} = Posts.delete_post(deleted)

      conn = get(conn, ~p"/api/v1/collections/#{collection.id}")

      assert %{"data" => [item]} = json_response(conn, 200)
      assert item["id"] == kept.id
    end

    test "renders posts with liked/bookmarked flags for the current user",
         %{conn: conn, user: user} do
      author = user_fixture()
      collection = collection_fixture(user)
      post_record = bookmarked_post_fixture(user, author)
      {:ok, _} = Collections.add_post(user, collection, post_record)

      conn = get(conn, ~p"/api/v1/collections/#{collection.id}")

      assert %{"data" => [item]} = json_response(conn, 200)
      assert item["bookmarked_by_current_user"] == true
      assert item["liked_by_current_user"] == false
      assert item["user"]["id"] == author.id
    end
  end

  describe "PATCH /api/v1/collections/:id" do
    test "renames the collection for a subscriber", %{conn: conn, user: user} do
      enable_paid_tier()
      subscribe(user)
      collection = collection_fixture(user, %{name: "Old name"})

      conn = patch(conn, ~p"/api/v1/collections/#{collection.id}", %{"name" => "New name"})

      assert %{"data" => %{"name" => "New name", "item_count" => 0}} = json_response(conn, 200)
    end
  end

  describe "unauthenticated requests" do
    test "return 401" do
      conn = build_conn() |> put_req_header("accept", "application/json")

      assert json_response(get(conn, ~p"/api/v1/collections"), 401)
      assert json_response(post(conn, ~p"/api/v1/collections", %{"name" => "X"}), 401)
    end
  end
end
