defmodule TraysSocial.MealPlansTest do
  # async: true — Trays Plus subscription gating lives in the controller, so
  # this context never reads the global :features config.
  use TraysSocial.DataCase, async: true

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.MealPlans
  alias TraysSocial.MealPlans.GroceryCheck
  alias TraysSocial.MealPlans.MealPlanEntry
  alias TraysSocial.Posts

  # A fixed week so nothing here depends on wall-clock time:
  # Monday 2026-03-02 .. Sunday 2026-03-08.
  @monday ~D[2026-03-02]
  @wednesday ~D[2026-03-04]
  @sunday ~D[2026-03-08]

  defp entry_fixture(user, date, post) do
    {:ok, entry} = MealPlans.create_entry(user, date, post)
    entry
  end

  defp bookmarked_post_fixture(user, author, attrs \\ %{}) do
    post = post_fixture(Map.put(attrs, :user_id, author.id))
    {:ok, _} = Posts.create_bookmark(user.id, post.id)
    post
  end

  defp ingredient_ids_by_name(post_id) do
    Map.new(Posts.get_post!(post_id).ingredients, &{&1.name, &1.id})
  end

  describe "create_entry/3" do
    test "plans a post the user authored, storing the exact date" do
      user = user_fixture()
      post = post_fixture(%{user_id: user.id})

      assert {:ok, %MealPlanEntry{} = entry} = MealPlans.create_entry(user, @wednesday, post)
      assert entry.user_id == user.id
      assert entry.post_id == post.id
      assert entry.date == @wednesday
    end

    test "plans a post the user bookmarked" do
      user = user_fixture()
      author = user_fixture()
      post = bookmarked_post_fixture(user, author)

      assert {:ok, %MealPlanEntry{}} = MealPlans.create_entry(user, @monday, post)
    end

    test "rejects a post the user neither bookmarked nor authored" do
      user = user_fixture()
      author = user_fixture()
      post = post_fixture(%{user_id: author.id})

      assert {:error, :forbidden} = MealPlans.create_entry(user, @monday, post)
      assert MealPlans.list_entries(user.id, @monday) == []
    end

    test "rejects planning the same post twice on the same day" do
      user = user_fixture()
      post = post_fixture(%{user_id: user.id})

      assert {:ok, _} = MealPlans.create_entry(user, @monday, post)
      assert {:error, changeset} = MealPlans.create_entry(user, @monday, post)
      assert %{user_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows the same post on a different day" do
      user = user_fixture()
      post = post_fixture(%{user_id: user.id})

      assert {:ok, _} = MealPlans.create_entry(user, @monday, post)
      assert {:ok, _} = MealPlans.create_entry(user, @wednesday, post)
    end
  end

  describe "list_entries/2" do
    test "includes Monday and Sunday, excludes the days just outside the window" do
      user = user_fixture()
      post = post_fixture(%{user_id: user.id})

      monday_entry = entry_fixture(user, @monday, post)
      sunday_entry = entry_fixture(user, @sunday, post)
      _day_before = entry_fixture(user, Date.add(@monday, -1), post)
      _day_after = entry_fixture(user, Date.add(@sunday, 1), post)

      assert [first, second] = MealPlans.list_entries(user.id, @monday)
      assert first.id == monday_entry.id
      assert second.id == sunday_entry.id
    end

    test "normalizes a non-Monday week_start to the same week" do
      user = user_fixture()
      post = post_fixture(%{user_id: user.id})
      entry = entry_fixture(user, @monday, post)

      assert [%{id: id}] = MealPlans.list_entries(user.id, @wednesday)
      assert id == entry.id
      assert [%{id: ^id}] = MealPlans.list_entries(user.id, @sunday)
    end

    test "orders by date then id and preloads the post's photos" do
      user = user_fixture()

      post =
        post_fixture(%{
          user_id: user.id,
          post_photos: [%{url: "/uploads/cover.jpg", position: 0}]
        })

      later = entry_fixture(user, @sunday, post)
      earlier = entry_fixture(user, @monday, post)

      assert [first, second] = MealPlans.list_entries(user.id, @monday)
      assert first.id == earlier.id
      assert second.id == later.id
      assert [%{url: "/uploads/cover.jpg"}] = first.post.post_photos
    end

    test "excludes entries for soft-deleted and moderator-removed posts" do
      user = user_fixture()
      admin = user_fixture()

      kept = post_fixture(%{user_id: user.id})
      deleted = post_fixture(%{user_id: user.id})
      removed = post_fixture(%{user_id: user.id})

      for post <- [kept, deleted, removed], do: entry_fixture(user, @monday, post)

      {:ok, _} = Posts.delete_post(deleted)
      {:ok, _} = Posts.remove_post(removed, %{removed_by_id: admin.id, reason: "test"})

      assert [entry] = MealPlans.list_entries(user.id, @monday)
      assert entry.post_id == kept.id
    end

    test "does not include other users' entries" do
      user = user_fixture()
      other = user_fixture()
      post = post_fixture(%{user_id: other.id})
      entry_fixture(other, @monday, post)

      assert MealPlans.list_entries(user.id, @monday) == []
    end
  end

  describe "delete_entry/2" do
    test "deletes the user's entry" do
      user = user_fixture()
      post = post_fixture(%{user_id: user.id})
      entry = entry_fixture(user, @monday, post)

      assert {:ok, %MealPlanEntry{}} = MealPlans.delete_entry(user.id, entry.id)
      refute Repo.get(MealPlanEntry, entry.id)
    end

    test "raises for another user's entry" do
      user = user_fixture()
      other = user_fixture()
      post = post_fixture(%{user_id: other.id})
      entry = entry_fixture(other, @monday, post)

      assert_raise Ecto.NoResultsError, fn ->
        MealPlans.delete_entry(user.id, entry.id)
      end

      assert Repo.get(MealPlanEntry, entry.id)
    end
  end

  describe "grocery_list/2" do
    test "groups per recipe with items in ingredient order and stable item keys" do
      user = user_fixture()

      post_a =
        post_fixture(%{
          user_id: user.id,
          caption: "Pancakes",
          post_photos: [%{url: "/uploads/pancakes.jpg", position: 0}],
          ingredients: [
            %{name: "Flour", quantity: "2", unit: "cups", order: 1},
            %{name: "Sugar", quantity: "1", unit: "cup", order: 0}
          ]
        })

      post_b =
        post_fixture(%{
          user_id: user.id,
          caption: "Soup",
          ingredients: [%{name: "Carrot", quantity: "3", unit: nil, order: 0}]
        })

      entry_fixture(user, @monday, post_a)
      entry_fixture(user, @wednesday, post_b)

      ids_a = ingredient_ids_by_name(post_a.id)
      ids_b = ingredient_ids_by_name(post_b.id)

      assert [group_a, group_b] = MealPlans.grocery_list(user.id, @monday)

      # The context returns the raw stored URL — thumbnailing is the JSON
      # view's job (see MealPlanJSON.render_grocery_list/1).
      assert group_a.post == %{
               id: post_a.id,
               caption: "Pancakes",
               photo_url: "/uploads/pancakes.jpg"
             }

      assert group_a.items == [
               %{
                 item_key: "#{post_a.id}:#{ids_a["Sugar"]}",
                 name: "Sugar",
                 quantity: "1",
                 unit: "cup",
                 checked: false
               },
               %{
                 item_key: "#{post_a.id}:#{ids_a["Flour"]}",
                 name: "Flour",
                 quantity: "2",
                 unit: "cups",
                 checked: false
               }
             ]

      assert group_b.post.id == post_b.id
      assert group_b.post.photo_url == nil

      assert [%{item_key: item_key, name: "Carrot", checked: false}] = group_b.items
      assert item_key == "#{post_b.id}:#{ids_b["Carrot"]}"
    end

    test "lists a post planned on two days of the week once, without duplicate items" do
      user = user_fixture()
      post = post_fixture(%{user_id: user.id})

      entry_fixture(user, @monday, post)
      entry_fixture(user, @wednesday, post)

      assert [group] = MealPlans.grocery_list(user.id, @monday)
      assert group.post.id == post.id
      assert [_only_item] = group.items
    end

    test "omits a planned post that has no ingredients" do
      user = user_fixture()
      # Non-recipe posts carry no ingredients; recipes require at least one.
      plain = post_fixture(%{user_id: user.id, type: "post", ingredients: []})
      recipe = post_fixture(%{user_id: user.id})

      entry_fixture(user, @monday, plain)
      entry_fixture(user, @monday, recipe)

      # The ingredient-less post still shows on the plan itself...
      assert [_, _] = MealPlans.list_entries(user.id, @monday)

      # ...but contributes no grocery group.
      assert [group] = MealPlans.grocery_list(user.id, @monday)
      assert group.post.id == recipe.id
    end

    test "excludes soft-deleted and moderator-removed posts" do
      user = user_fixture()
      admin = user_fixture()

      kept = post_fixture(%{user_id: user.id})
      deleted = post_fixture(%{user_id: user.id})
      removed = post_fixture(%{user_id: user.id})

      for post <- [kept, deleted, removed], do: entry_fixture(user, @monday, post)

      {:ok, _} = Posts.delete_post(deleted)
      {:ok, _} = Posts.remove_post(removed, %{removed_by_id: admin.id, reason: "test"})

      assert [group] = MealPlans.grocery_list(user.id, @monday)
      assert group.post.id == kept.id
    end

    test "marks checked items for the requested week only" do
      user = user_fixture()
      post = post_fixture(%{user_id: user.id})
      entry_fixture(user, @monday, post)

      next_monday = Date.add(@monday, 7)
      entry_fixture(user, next_monday, post)

      [%{items: [%{item_key: item_key}]}] = MealPlans.grocery_list(user.id, @monday)
      assert :ok = MealPlans.set_check(user.id, @monday, item_key, true)

      # Checked in the week it was set — regardless of which day is queried.
      assert [%{items: [%{checked: true}]}] = MealPlans.grocery_list(user.id, @sunday)

      # The same item_key in the following week is independent.
      assert [%{items: [%{checked: false}]}] = MealPlans.grocery_list(user.id, next_monday)
    end
  end

  describe "set_check/4" do
    test "checking twice is idempotent and stores one Monday-keyed row" do
      user = user_fixture()

      assert :ok = MealPlans.set_check(user.id, @wednesday, "1:2", true)
      assert :ok = MealPlans.set_check(user.id, @wednesday, "1:2", true)

      assert [check] = Repo.all(GroceryCheck)
      assert check.user_id == user.id
      assert check.week_start == @monday
      assert check.item_key == "1:2"
    end

    test "unchecking twice is idempotent" do
      user = user_fixture()
      assert :ok = MealPlans.set_check(user.id, @monday, "1:2", true)

      assert :ok = MealPlans.set_check(user.id, @wednesday, "1:2", false)
      assert :ok = MealPlans.set_check(user.id, @wednesday, "1:2", false)

      assert Repo.all(GroceryCheck) == []
    end

    test "the same item_key in different weeks is tracked independently" do
      user = user_fixture()
      next_monday = Date.add(@monday, 7)

      assert :ok = MealPlans.set_check(user.id, @monday, "1:2", true)
      assert :ok = MealPlans.set_check(user.id, next_monday, "1:2", true)
      assert length(Repo.all(GroceryCheck)) == 2

      assert :ok = MealPlans.set_check(user.id, @monday, "1:2", false)
      assert [%{week_start: ^next_monday}] = Repo.all(GroceryCheck)
    end

    test "rejects an item_key that is not \"int:int\"" do
      user = user_fixture()

      for bad <- ["abc", "1:2:3", "12", "1:a", ":2", "1:"] do
        assert {:error, %Ecto.Changeset{} = changeset} =
                 MealPlans.set_check(user.id, @monday, bad, true)

        assert %{item_key: [message]} = errors_on(changeset)
        assert message =~ "post_id:ingredient_id"
      end

      assert {:error, changeset} = MealPlans.set_check(user.id, @monday, nil, false)
      assert %{item_key: ["can't be blank"]} = errors_on(changeset)
      assert Repo.all(GroceryCheck) == []
    end
  end
end
