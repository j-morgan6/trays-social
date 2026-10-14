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

  describe "prune_grocery_checks/1" do
    # "Today" is the Wednesday of the fixed week, so the current week's
    # Monday is @monday. With retention_weeks: 2 the cutoff is @monday - 14.
    @today @wednesday

    defp check_fixture(user, week_start, item_key \\ "1:2") do
      :ok = MealPlans.set_check(user.id, week_start, item_key, true)
    end

    defp weeks_ago(n), do: Date.add(@monday, -7 * n)

    defp remaining_week_starts do
      GroceryCheck
      |> Repo.all()
      |> Enum.map(& &1.week_start)
      |> Enum.sort(Date)
    end

    test "deletes rows older than the window and keeps rows inside it" do
      user = user_fixture()
      for n <- [0, 1, 2, 3, 5], do: check_fixture(user, weeks_ago(n))

      assert {:ok, 2} = MealPlans.prune_grocery_checks(retention_weeks: 2, today: @today)

      assert remaining_week_starts() == [weeks_ago(2), weeks_ago(1), @monday]
    end

    test "keeps a row exactly on the Monday cutoff boundary" do
      user = user_fixture()
      cutoff = weeks_ago(2)
      check_fixture(user, cutoff)
      # The day before the cutoff Monday normalizes to the previous week.
      check_fixture(user, Date.add(cutoff, -1))

      assert {:ok, 1} = MealPlans.prune_grocery_checks(retention_weeks: 2, today: @today)
      assert remaining_week_starts() == [cutoff]
    end

    test "the cutoff does not depend on which day of the week today is" do
      user = user_fixture()
      check_fixture(user, weeks_ago(1))
      check_fixture(user, weeks_ago(2))

      for today <- [@monday, @wednesday, @sunday] do
        assert {:ok, _} = MealPlans.prune_grocery_checks(retention_weeks: 1, today: today)
        assert remaining_week_starts() == [weeks_ago(1)]
      end
    end

    test "never deletes the current week's or a future week's rows" do
      user = user_fixture()
      check_fixture(user, @monday)
      check_fixture(user, @sunday, "3:4")
      check_fixture(user, Date.add(@monday, 7))
      check_fixture(user, weeks_ago(1))

      # The smallest legal window still spares this week and next.
      assert {:ok, 0} = MealPlans.prune_grocery_checks(retention_weeks: 1, today: @sunday)

      assert {:ok, 1} =
               MealPlans.prune_grocery_checks(retention_weeks: 1, today: Date.add(@monday, 7))

      assert remaining_week_starts() == [@monday, @monday, Date.add(@monday, 7)]
    end

    test "rejects a retention window that is not a positive integer" do
      user = user_fixture()
      check_fixture(user, @monday)

      for bad <- [0, -1, 1.5, "8", nil] do
        assert_raise ArgumentError, ~r/retention_weeks must be a positive integer/, fn ->
          MealPlans.prune_grocery_checks(retention_weeks: bad, today: @today)
        end
      end

      assert remaining_week_starts() == [@monday]
    end

    test "is a no-op on an empty table" do
      assert {:ok, 0} = MealPlans.prune_grocery_checks(retention_weeks: 2, today: @today)
    end

    test "is a no-op when every row is inside the window" do
      user = user_fixture()
      check_fixture(user, @monday)
      check_fixture(user, weeks_ago(1))

      assert {:ok, 0} = MealPlans.prune_grocery_checks(retention_weeks: 2, today: @today)
      assert length(Repo.all(GroceryCheck)) == 2
    end

    test "running it twice is idempotent" do
      user = user_fixture()
      check_fixture(user, weeks_ago(4))
      check_fixture(user, @monday)

      assert {:ok, 1} = MealPlans.prune_grocery_checks(retention_weeks: 2, today: @today)
      assert {:ok, 0} = MealPlans.prune_grocery_checks(retention_weeks: 2, today: @today)
      assert remaining_week_starts() == [@monday]
    end

    test "prunes every user's stale rows, including a user who planned nothing for weeks" do
      active = user_fixture()
      lapsed = user_fixture()

      check_fixture(active, @monday)
      check_fixture(active, weeks_ago(10))
      for n <- [20, 30, 40], do: check_fixture(lapsed, weeks_ago(n))

      assert {:ok, 4} = MealPlans.prune_grocery_checks(retention_weeks: 2, today: @today)
      assert [%{user_id: user_id}] = Repo.all(GroceryCheck)
      assert user_id == active.id
    end

    test "defaults retention_weeks to the configured value" do
      configured = Application.get_env(:trays_social, :grocery_checks)[:retention_weeks]
      assert is_integer(configured) and configured >= 1

      user = user_fixture()
      check_fixture(user, weeks_ago(configured))
      check_fixture(user, weeks_ago(configured + 1))

      assert {:ok, 1} = MealPlans.prune_grocery_checks(today: @today)
      assert remaining_week_starts() == [weeks_ago(configured)]
    end

    test "a pruned past week's grocery list still renders, with everything unchecked" do
      user = user_fixture()
      post = post_fixture(%{user_id: user.id})
      old_monday = weeks_ago(4)
      entry_fixture(user, old_monday, post)
      entry_fixture(user, @monday, post)

      [%{items: [%{item_key: item_key}]}] = MealPlans.grocery_list(user.id, old_monday)
      :ok = MealPlans.set_check(user.id, old_monday, item_key, true)
      :ok = MealPlans.set_check(user.id, @monday, item_key, true)

      assert {:ok, 1} = MealPlans.prune_grocery_checks(retention_weeks: 2, today: @today)

      assert [%{post: %{id: post_id}, items: [%{item_key: ^item_key, checked: false}]}] =
               MealPlans.grocery_list(user.id, old_monday)

      assert post_id == post.id

      # The current week's check survives the prune.
      assert [%{items: [%{checked: true}]}] = MealPlans.grocery_list(user.id, @monday)
    end
  end
end
