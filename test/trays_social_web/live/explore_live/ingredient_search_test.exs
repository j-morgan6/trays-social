defmodule TraysSocialWeb.ExploreLive.IngredientSearchTest do
  use TraysSocialWeb.ConnCase

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Accounts

  setup %{conn: conn} do
    viewer = user_fixture()
    %{conn: log_in_user(conn, viewer), viewer: viewer}
  end

  defp recipe(user, caption, names) do
    ingredients = Enum.map(names, &%{name: &1, quantity: "1", unit: ""})
    post_fixture(%{user_id: user.id, caption: caption, ingredients: ingredients})
  end

  defp explore(conn) do
    {:ok, view, _html} = live(conn, ~p"/explore")
    view
  end

  defp add(view, text), do: render_submit(view, "add-ingredient", %{"ingredient" => text})

  describe "single search box" do
    test "there is no Recipes / What I have switch", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/explore")

      refute html =~ "What I have"
      refute has_element?(view, "[aria-label='Search mode']")
      refute has_element?(view, "#ingredient-form")
      assert has_element?(view, "#search-form input[name='query']")
    end

    test "Enter turns the typed text into a chip and empties the box", %{conn: conn} do
      view = explore(conn)
      view |> form("#search-form", %{"query" => "Rice"}) |> render_change()
      assert has_element?(view, "#search-input-0[value='Rice']")

      view |> form("#search-form", %{"query" => "Rice"}) |> render_submit()

      assert has_element?(view, "button[aria-label='Remove rice']")
      assert has_element?(view, "#search-input-1[value='']")
      assert render(view) =~ "Add two or more"
    end

    test "new chips are pushed to the SearchPrefs hook", %{conn: conn} do
      view = explore(conn)
      render_hook(view, "restore-search-prefs", %{"recent" => ["eggs"]})

      add(view, "rice")
      assert_push_event(view, "search-prefs", %{recent: ["rice", "eggs"]})
    end

    test "nothing is pushed before the hook has restored stored prefs", %{conn: conn} do
      # A fresh mount or a rejoin starts from defaults; pushing those would
      # overwrite what the browser stored before the hook sends it back.
      view = explore(conn)
      add(view, "rice")

      refute_push_event(view, "search-prefs", %{})
    end
  end

  describe "ingredient chips" do
    test "adding ingredients groups results with missing lists", %{conn: conn, viewer: viewer} do
      cook = user_fixture()
      recipe(viewer, "Lemon rice", ["rice", "lemon"])
      recipe(cook, "Chicken adobo", ["rice", "soy sauce"])

      view = explore(conn)
      add(view, "Rice")
      html = add(view, "lemon")

      assert html =~ "You have everything"
      assert html =~ "Lemon rice"
      assert html =~ "Almost there"
      assert html =~ "Chicken adobo"
      assert html =~ "missing: soy sauce"
    end

    test "removing chips steps back to normal search, then to nothing", %{
      conn: conn,
      viewer: viewer
    } do
      recipe(viewer, "Lemon rice", ["rice", "lemon"])

      view = explore(conn)
      add(view, "rice")
      assert add(view, "lemon") =~ "You have everything"

      html = render_click(view, "remove-ingredient", %{"ingredient" => "lemon"})

      refute html =~ "You have everything"
      assert html =~ "1 recipe for you"

      html = render_click(view, "remove-ingredient", %{"ingredient" => "rice"})

      refute html =~ "1 recipe for you"
      assert html =~ "Popular this week"
      refute has_element?(view, "button[aria-label^='Remove']")
    end

    test "an eleventh chip is ignored", %{conn: conn} do
      view = explore(conn)
      for i <- 1..11, do: add(view, "item#{i}")

      assert has_element?(view, "button[aria-label='Remove item10']")
      refute has_element?(view, "button[aria-label='Remove item11']")
      assert render(view) =~ "Up to 10 ingredients"
    end

    test "duplicate chips are collapsed case-insensitively", %{conn: conn} do
      view = explore(conn)
      add(view, "Rice")
      html = add(view, "  rice ")

      assert length(Regex.scan(~r/aria-label="Remove rice"/, html)) == 1
    end

    test "invalid add-ingredient payloads add no chip", %{conn: conn} do
      view = explore(conn)

      render_submit(view, "add-ingredient", %{"ingredient" => ["x"]})
      render_submit(view, "add-ingredient", %{})
      add(view, "   ")
      add(view, String.duplicate("a", 51))
      add(view, "x\u0000y")

      refute has_element?(view, "button[aria-label^='Remove']")
    end

    test "a junk remove-ingredient payload is ignored", %{conn: conn} do
      view = explore(conn)
      add(view, "rice")

      render_click(view, "remove-ingredient", %{"ingredient" => %{"a" => 1}})

      assert has_element?(view, "button[aria-label='Remove rice']")
    end

    test "recipes by blocked cooks are excluded", %{conn: conn, viewer: viewer} do
      cook = user_fixture()
      recipe(cook, "Blocked fried rice", ["rice", "egg"])
      {:ok, _} = Accounts.block_user(viewer.id, cook.id)

      view = explore(conn)
      add(view, "rice")
      html = add(view, "egg")

      refute html =~ "Blocked fried rice"
      assert html =~ "No matches yet"
    end
  end

  describe "blocked cooks on the normal search" do
    # One term on the classic page goes to Posts.search_posts, which must get
    # the viewer's block pairs like the grouped and ingredient searches do.
    test "a single chip or typed term never shows a blocked cook's recipe", %{
      conn: conn,
      viewer: viewer
    } do
      cook = user_fixture()
      recipe(cook, "Blocked rice bowl", ["rice"])
      recipe(user_fixture(), "Open rice bowl", ["rice"])
      {:ok, _} = Accounts.block_user(cook.id, viewer.id)

      view = explore(conn)
      html = view |> form("#search-form", %{"query" => "rice"}) |> render_change()

      assert html =~ "Open rice bowl"
      refute html =~ "Blocked rice bowl"

      html = view |> form("#search-form", %{"query" => "rice"}) |> render_submit()

      assert has_element?(view, "button[aria-label='Remove rice']")
      assert html =~ "Open rice bowl"
      refute html =~ "Blocked rice bowl"
    end
  end

  describe "restore-search-prefs" do
    test "restore-search-prefs shows recently used chips", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/explore")

      html = render_hook(view, "restore-search-prefs", %{"mode" => "have", "recent" => ["eggs"]})

      assert has_element?(view, "#search-form")
      assert has_element?(view, "button[phx-value-ingredient='eggs']")
      assert html =~ "Recently used"
    end

    test "a recent chip can be re-added with one click", %{conn: conn, viewer: viewer} do
      recipe(viewer, "Scrambled eggs", ["egg", "butter"])
      {:ok, view, _html} = live(conn, ~p"/explore")
      render_hook(view, "restore-search-prefs", %{"recent" => ["eggs", "butter"]})

      view |> element("button[phx-value-ingredient='eggs']") |> render_click()
      html = view |> element("button[phx-value-ingredient='butter']") |> render_click()

      assert has_element?(view, "button[aria-label='Remove eggs']")
      assert html =~ "Scrambled eggs"
    end

    test "junk and legacy mode values fall back safely", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/explore")

      html =
        render_hook(view, "restore-search-prefs", %{"mode" => "admin", "recent" => %{"a" => 1}})

      assert html =~ "Search recipes"

      html = render_hook(view, "restore-search-prefs", %{"mode" => 5, "recent" => "not-a-list"})
      assert html =~ "Search recipes"

      long = String.duplicate("a", 51)

      render_hook(view, "restore-search-prefs", %{
        "mode" => "have",
        "recent" => [1, nil, long, "ok", "x\u0000y", ["nested"]]
      })

      assert has_element?(view, "button[phx-value-ingredient='ok']")
      refute render(view) =~ long
      assert length(Regex.scan(~r/phx-value-ingredient=/, render(view))) == 1
    end

    test "at most ten recent chips are kept", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/explore")
      recent = for i <- 1..15, do: "food#{i}"

      html = render_hook(view, "restore-search-prefs", %{"mode" => "have", "recent" => recent})

      assert length(Regex.scan(~r/phx-value-ingredient=/, html)) == 10
      assert html =~ "food10"
      refute html =~ "food11"
    end

    test "restoring does not wipe the current chips", %{conn: conn} do
      view = explore(conn)
      add(view, "rice")

      render_hook(view, "restore-search-prefs", %{"mode" => "have", "recent" => []})

      assert has_element?(view, "button[aria-label='Remove rice']")
    end
  end
end
