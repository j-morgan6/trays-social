defmodule TraysSocial.CollectionsTest do
  # async: true — Trays Plus subscription gating lives in the controller, so
  # this context never reads the global :features config.
  use TraysSocial.DataCase, async: true

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Collections
  alias TraysSocial.Collections.Collection
  alias TraysSocial.Collections.CollectionItem
  alias TraysSocial.Posts

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

  describe "create_collection/2" do
    test "with valid attrs creates a collection" do
      user = user_fixture()

      assert {:ok, %Collection{} = collection} =
               Collections.create_collection(user.id, %{name: "Desserts"})

      assert collection.name == "Desserts"
      assert collection.user_id == user.id
    end

    test "requires a name" do
      user = user_fixture()

      assert {:error, changeset} = Collections.create_collection(user.id, %{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects a name over 60 characters" do
      user = user_fixture()
      long_name = String.duplicate("a", 61)

      assert {:error, changeset} = Collections.create_collection(user.id, %{name: long_name})
      assert %{name: ["should be at most 60 character(s)"]} = errors_on(changeset)
    end

    test "rejects a duplicate name for the same user" do
      user = user_fixture()
      collection_fixture(user, %{name: "Desserts"})

      assert {:error, changeset} = Collections.create_collection(user.id, %{name: "Desserts"})
      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows the same name for different users" do
      user = user_fixture()
      other = user_fixture()
      collection_fixture(user, %{name: "Desserts"})

      assert {:ok, %Collection{}} = Collections.create_collection(other.id, %{name: "Desserts"})
    end
  end

  describe "rename_collection/2" do
    test "renames a collection" do
      user = user_fixture()
      collection = collection_fixture(user, %{name: "Old name"})

      assert {:ok, %Collection{name: "New name"}} =
               Collections.rename_collection(collection, %{name: "New name"})
    end

    test "rejects a blank name" do
      user = user_fixture()
      collection = collection_fixture(user)

      assert {:error, changeset} = Collections.rename_collection(collection, %{name: ""})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects renaming to another of the user's collection names" do
      user = user_fixture()
      collection_fixture(user, %{name: "Taken"})
      collection = collection_fixture(user, %{name: "Original"})

      assert {:error, changeset} = Collections.rename_collection(collection, %{name: "Taken"})
      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "get_collection!/2" do
    test "returns the user's collection" do
      user = user_fixture()
      collection = collection_fixture(user)

      assert Collections.get_collection!(user.id, collection.id).id == collection.id
    end

    test "raises for another user's collection" do
      user = user_fixture()
      other = user_fixture()
      collection = collection_fixture(other)

      assert_raise Ecto.NoResultsError, fn ->
        Collections.get_collection!(user.id, collection.id)
      end
    end
  end

  describe "add_post/3" do
    test "adds a post the user authored" do
      user = user_fixture()
      collection = collection_fixture(user)
      post = post_fixture(%{user_id: user.id})

      assert {:ok, %CollectionItem{} = item} = Collections.add_post(user, collection, post)
      assert item.collection_id == collection.id
      assert item.post_id == post.id
    end

    test "adds a post the user bookmarked" do
      user = user_fixture()
      author = user_fixture()
      collection = collection_fixture(user)
      post = bookmarked_post_fixture(user, author)

      assert {:ok, %CollectionItem{}} = Collections.add_post(user, collection, post)
    end

    test "rejects a post the user neither bookmarked nor authored" do
      user = user_fixture()
      author = user_fixture()
      collection = collection_fixture(user)
      post = post_fixture(%{user_id: author.id})

      assert {:error, :forbidden} = Collections.add_post(user, collection, post)
      assert Collections.list_collection_items(collection.id) == []
    end

    test "rejects adding the same post twice" do
      user = user_fixture()
      collection = collection_fixture(user)
      post = post_fixture(%{user_id: user.id})

      assert {:ok, _} = Collections.add_post(user, collection, post)
      assert {:error, changeset} = Collections.add_post(user, collection, post)
      assert %{collection_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "remove_post/2" do
    test "removes a post from a collection" do
      user = user_fixture()
      collection = collection_fixture(user)
      post = post_fixture(%{user_id: user.id})
      {:ok, _} = Collections.add_post(user, collection, post)

      assert {:ok, %CollectionItem{}} = Collections.remove_post(collection, post.id)
      assert Collections.list_collection_items(collection.id) == []
    end

    test "returns not_found when the post is not in the collection" do
      user = user_fixture()
      collection = collection_fixture(user)
      post = post_fixture(%{user_id: user.id})

      assert {:error, :not_found} = Collections.remove_post(collection, post.id)
    end
  end

  describe "delete_collection/1" do
    test "deletes the collection and its items but preserves bookmarks and posts" do
      user = user_fixture()
      author = user_fixture()
      collection = collection_fixture(user)
      post = bookmarked_post_fixture(user, author)
      {:ok, item} = Collections.add_post(user, collection, post)

      assert {:ok, %Collection{}} = Collections.delete_collection(collection)

      refute Repo.get(Collection, collection.id)
      refute Repo.get(CollectionItem, item.id)
      assert Posts.bookmarked?(user.id, post.id)
      assert Posts.get_post!(post.id).id == post.id
    end
  end

  describe "list_collections/1" do
    test "returns summaries with item_count and cover photo, newest collection first" do
      user = user_fixture()
      first = collection_fixture(user, %{name: "First"})
      second = collection_fixture(user, %{name: "Second"})

      older = post_fixture(%{user_id: user.id})

      newest =
        post_fixture(%{
          user_id: user.id,
          post_photos: [%{url: "/uploads/cover.jpg", position: 0}]
        })

      {:ok, _} = Collections.add_post(user, second, older)
      {:ok, _} = Collections.add_post(user, second, newest)

      assert [
               %{collection: %{name: "Second"}, item_count: 2, cover_photo_url: cover},
               %{collection: %{name: "First"}, item_count: 0, cover_photo_url: nil}
             ] = Collections.list_collections(user.id)

      # Cover is the position-0 photo of the most recently ADDED member post.
      assert cover == "/uploads/cover.jpg"
    end

    test "does not include other users' collections" do
      user = user_fixture()
      other = user_fixture()
      collection_fixture(other)

      assert Collections.list_collections(user.id) == []
    end

    test "excludes deleted posts from item_count and cover" do
      user = user_fixture()
      collection = collection_fixture(user)

      kept =
        post_fixture(%{
          user_id: user.id,
          post_photos: [%{url: "/uploads/kept.jpg", position: 0}]
        })

      deleted =
        post_fixture(%{
          user_id: user.id,
          post_photos: [%{url: "/uploads/deleted.jpg", position: 0}]
        })

      {:ok, _} = Collections.add_post(user, collection, kept)
      {:ok, _} = Collections.add_post(user, collection, deleted)
      {:ok, _} = Posts.delete_post(deleted)

      assert [%{item_count: 1, cover_photo_url: "/uploads/kept.jpg"}] =
               Collections.list_collections(user.id)
    end
  end

  describe "list_collection_items/2" do
    test "paginates with a cursor, newest first" do
      user = user_fixture()
      collection = collection_fixture(user)

      posts = for _ <- 1..3, do: post_fixture(%{user_id: user.id})
      items = for post <- posts, do: elem(Collections.add_post(user, collection, post), 1)
      [oldest, middle, newest] = items

      assert [first, second] = Collections.list_collection_items(collection.id, limit: 2)
      assert first.id == newest.id
      assert second.id == middle.id

      assert [third] =
               Collections.list_collection_items(collection.id,
                 limit: 2,
                 cursor_id: second.id,
                 cursor_time: second.inserted_at
               )

      assert third.id == oldest.id
    end

    test "excludes deleted and removed posts" do
      user = user_fixture()
      admin = user_fixture()
      collection = collection_fixture(user)

      kept = post_fixture(%{user_id: user.id})
      deleted = post_fixture(%{user_id: user.id})
      removed = post_fixture(%{user_id: user.id})

      for post <- [kept, deleted, removed] do
        {:ok, _} = Collections.add_post(user, collection, post)
      end

      {:ok, _} = Posts.delete_post(deleted)
      {:ok, _} = Posts.remove_post(removed, %{removed_by_id: admin.id, reason: "test"})

      assert [item] = Collections.list_collection_items(collection.id)
      assert item.post.id == kept.id
    end

    test "preloads the post associations PostJSON renders" do
      user = user_fixture()
      collection = collection_fixture(user)
      post = post_fixture(%{user_id: user.id})
      {:ok, _} = Collections.add_post(user, collection, post)

      assert [item] = Collections.list_collection_items(collection.id)
      assert item.post.user.id == user.id
      assert is_list(item.post.post_photos)
      assert is_list(item.post.ingredients)
    end
  end
end
