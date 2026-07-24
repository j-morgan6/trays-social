defmodule TraysSocialWeb.API.V1.MealPlanControllerTest do
  # async: false — these tests toggle the global :paid_tier feature flag via
  # Application.put_env/3 (G38/W173); running serially keeps that mutation
  # from racing other tests that read :features.
  use TraysSocialWeb.ConnCase, async: false

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.MealPlans
  alias TraysSocial.Posts

  setup :register_and_api_authenticate_user

  # A fixed week so nothing here depends on wall-clock time:
  # Monday 2026-03-02 .. Sunday 2026-03-08.
  @monday "2026-03-02"
  @wednesday "2026-03-04"

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

  defp bookmarked_post_fixture(user, author, attrs \\ %{}) do
    post = post_fixture(Map.put(attrs, :user_id, author.id))
    {:ok, _} = Posts.create_bookmark(user.id, post.id)
    post
  end

  defp entry_fixture(user, date, post) do
    {:ok, entry} = MealPlans.create_entry(user, date, post)
    entry
  end

  describe "full subscriber flow" do
    test "plan two posts, derive the grocery list, check an item", %{conn: conn, user: user} do
      enable_paid_tier()
      subscribe(user)
      author = user_fixture()

      planned_a =
        bookmarked_post_fixture(user, author, %{
          caption: "Pancakes",
          post_photos: [%{url: "/uploads/pancakes.jpg", position: 0}]
        })

      planned_b = post_fixture(%{user_id: user.id, caption: "Soup"})

      # Plan both posts (Monday and Wednesday of the same week)
      create_a =
        post(conn, ~p"/api/v1/meal-plan/entries", %{
          "date" => @monday,
          "post_id" => planned_a.id
        })

      assert %{"data" => %{"id" => _, "date" => @monday, "post" => rendered_post}} =
               json_response(create_a, 201)

      assert rendered_post["id"] == planned_a.id
      assert rendered_post["caption"] == "Pancakes"
      assert rendered_post["thumbnail_url"] == "/uploads/pancakes_thumb.jpg"
      assert rendered_post["cooking_time_minutes"] == 42
      assert rendered_post["type"] == "recipe"

      create_b =
        post(conn, ~p"/api/v1/meal-plan/entries", %{
          "date" => @wednesday,
          "post_id" => planned_b.id
        })

      assert %{"data" => %{"post" => %{"thumbnail_url" => nil}}} = json_response(create_b, 201)

      # The week view normalizes any queried day to Monday
      plan_conn = get(conn, ~p"/api/v1/meal-plan?week_start=#{@wednesday}")

      assert %{"data" => %{"week_start" => @monday, "entries" => [entry_a, entry_b]}} =
               json_response(plan_conn, 200)

      assert entry_a["date"] == @monday
      assert entry_a["post"]["id"] == planned_a.id
      assert entry_b["date"] == @wednesday
      assert entry_b["post"]["id"] == planned_b.id

      # Grocery list: one group per recipe, everything unchecked
      grocery_conn = get(conn, ~p"/api/v1/meal-plan/grocery-list?week_start=#{@wednesday}")

      assert %{"data" => %{"week_start" => @monday, "recipes" => recipes}} =
               json_response(grocery_conn, 200)

      assert [%{"items" => [item | _]} | _] = recipes
      recipe_post_ids = recipes |> Enum.map(& &1["post"]["id"]) |> Enum.sort()
      assert recipe_post_ids == [planned_a.id, planned_b.id]
      assert %{"item_key" => item_key, "name" => _, "checked" => false} = item

      # Check one item
      check_conn =
        put(conn, ~p"/api/v1/meal-plan/grocery-checks", %{
          "week_start" => @wednesday,
          "item_key" => item_key,
          "checked" => true
        })

      assert %{"data" => %{"message" => "check updated"}} = json_response(check_conn, 200)

      # Refetch: only that item is checked
      refetch_conn = get(conn, ~p"/api/v1/meal-plan/grocery-list?week_start=#{@monday}")
      %{"data" => %{"recipes" => refetched}} = json_response(refetch_conn, 200)

      checked_keys =
        for recipe <- refetched, item <- recipe["items"], item["checked"], do: item["item_key"]

      assert checked_keys == [item_key]
    end
  end

  describe "subscription gating" do
    test "non-subscriber with flag on gets 403 subscription_required on entry creation",
         %{conn: conn, user: user} do
      enable_paid_tier()
      post_record = post_fixture(%{user_id: user.id})

      conn =
        post(conn, ~p"/api/v1/meal-plan/entries", %{
          "date" => @monday,
          "post_id" => post_record.id
        })

      assert %{"errors" => [%{"code" => "subscription_required", "message" => message}]} =
               json_response(conn, 403)

      assert message == "Trays Plus subscription required"
    end

    test "subscriber with flag off gets 403 subscription_required on entry creation",
         %{conn: conn, user: user} do
      subscribe(user)
      post_record = post_fixture(%{user_id: user.id})

      conn =
        post(conn, ~p"/api/v1/meal-plan/entries", %{
          "date" => @monday,
          "post_id" => post_record.id
        })

      assert %{"errors" => [%{"code" => "subscription_required"}]} = json_response(conn, 403)
    end

    test "non-subscriber can still read the plan, delete entries, and toggle checks",
         %{conn: conn, user: user} do
      # Graceful re-lock: the plan was built while subscribed; the lapsed
      # user keeps read, delete, and check access to their own data.
      post_record = post_fixture(%{user_id: user.id})
      entry = entry_fixture(user, ~D[2026-03-02], post_record)

      assert %{"data" => %{"entries" => [_]}} =
               json_response(get(conn, ~p"/api/v1/meal-plan?week_start=#{@monday}"), 200)

      assert %{"data" => %{"recipes" => [%{"items" => [%{"item_key" => item_key}]}]}} =
               json_response(
                 get(conn, ~p"/api/v1/meal-plan/grocery-list?week_start=#{@monday}"),
                 200
               )

      check_conn =
        put(conn, ~p"/api/v1/meal-plan/grocery-checks", %{
          "week_start" => @monday,
          "item_key" => item_key,
          "checked" => true
        })

      assert %{"data" => %{"message" => "check updated"}} = json_response(check_conn, 200)

      delete_conn = delete(conn, ~p"/api/v1/meal-plan/entries/#{entry.id}")
      assert %{"data" => %{"message" => "entry deleted"}} = json_response(delete_conn, 200)
    end
  end

  describe "week_start parsing" do
    test "invalid week_start returns 422 on both reads", %{conn: conn} do
      for path <- [
            ~p"/api/v1/meal-plan?week_start=not-a-date",
            ~p"/api/v1/meal-plan/grocery-list?week_start=2026-13-40"
          ] do
        assert %{"errors" => [%{"field" => "week_start", "message" => message}]} =
                 json_response(get(conn, path), 422)

        assert message =~ "ISO 8601"
      end
    end

    test "missing week_start defaults to the current week", %{conn: conn, user: user} do
      post_record = post_fixture(%{user_id: user.id})
      entry_fixture(user, Date.utc_today(), post_record)

      this_monday = Date.utc_today() |> Date.beginning_of_week() |> Date.to_iso8601()

      assert %{"data" => %{"week_start" => ^this_monday, "entries" => [_]}} =
               json_response(get(conn, ~p"/api/v1/meal-plan"), 200)
    end
  end

  describe "POST /api/v1/meal-plan/entries validation" do
    setup %{user: user} do
      enable_paid_tier()
      subscribe(user)
      :ok
    end

    test "planning a post the user neither bookmarked nor authored returns 403",
         %{conn: conn} do
      author = user_fixture()
      post_record = post_fixture(%{user_id: author.id})

      conn =
        post(conn, ~p"/api/v1/meal-plan/entries", %{
          "date" => @monday,
          "post_id" => post_record.id
        })

      assert %{"errors" => [%{"message" => "forbidden"}]} = json_response(conn, 403)
    end

    test "unknown and non-numeric post ids return 404", %{conn: conn} do
      for post_id <- [0, "abc"] do
        conn =
          post(conn, ~p"/api/v1/meal-plan/entries", %{"date" => @monday, "post_id" => post_id})

        assert %{"errors" => [%{"message" => "not found"}]} = json_response(conn, 404)
      end
    end

    test "missing or invalid date returns 422", %{conn: conn, user: user} do
      post_record = post_fixture(%{user_id: user.id})

      for params <- [
            %{"post_id" => post_record.id},
            %{"date" => "03/02/2026", "post_id" => post_record.id}
          ] do
        conn = post(conn, ~p"/api/v1/meal-plan/entries", params)

        assert %{"errors" => [%{"field" => "date", "message" => message}]} =
                 json_response(conn, 422)

        assert message =~ "ISO 8601"
      end
    end
  end

  describe "DELETE /api/v1/meal-plan/entries/:id" do
    test "another user's entry is a 404", %{conn: conn} do
      other = user_fixture()
      post_record = post_fixture(%{user_id: other.id})
      entry = entry_fixture(other, ~D[2026-03-02], post_record)

      conn = delete(conn, ~p"/api/v1/meal-plan/entries/#{entry.id}")

      assert %{"errors" => [%{"message" => "not found"}]} = json_response(conn, 404)
    end

    test "a non-numeric entry id is a 404", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/meal-plan/entries/abc")

      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/v1/meal-plan/grocery-checks validation" do
    test "invalid item_key returns a changeset error", %{conn: conn} do
      conn =
        put(conn, ~p"/api/v1/meal-plan/grocery-checks", %{
          "week_start" => @monday,
          "item_key" => "not-a-key",
          "checked" => true
        })

      assert %{"errors" => [%{"field" => "item_key", "message" => message}]} =
               json_response(conn, 422)

      assert message =~ "post_id:ingredient_id"
    end

    test "non-boolean checked returns 422", %{conn: conn} do
      conn =
        put(conn, ~p"/api/v1/meal-plan/grocery-checks", %{
          "week_start" => @monday,
          "item_key" => "1:2",
          "checked" => "yes"
        })

      assert %{"errors" => [%{"field" => "checked", "message" => "must be a boolean"}]} =
               json_response(conn, 422)
    end
  end

  describe "unauthenticated requests" do
    test "return 401" do
      conn = build_conn() |> put_req_header("accept", "application/json")

      assert json_response(get(conn, ~p"/api/v1/meal-plan"), 401)
      assert json_response(get(conn, ~p"/api/v1/meal-plan/grocery-list"), 401)

      assert json_response(
               post(conn, ~p"/api/v1/meal-plan/entries", %{"date" => @monday, "post_id" => 1}),
               401
             )

      assert json_response(delete(conn, ~p"/api/v1/meal-plan/entries/1"), 401)

      assert json_response(
               put(conn, ~p"/api/v1/meal-plan/grocery-checks", %{
                 "week_start" => @monday,
                 "item_key" => "1:2",
                 "checked" => true
               }),
               401
             )
    end
  end
end
