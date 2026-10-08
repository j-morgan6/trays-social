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

  defp have_mode(conn) do
    {:ok, view, _html} = live(conn, ~p"/explore")
    render_click(view, "set-mode", %{"mode" => "have"})
    view
  end

  defp add(view, text), do: render_submit(view, "add-ingredient", %{"ingredient" => text})

  describe "mode switch" do
    test "switching to What I have shows the ingredient input", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/explore")

      assert html =~ "Recipes"
      assert html =~ "What I have"
      refute has_element?(view, "#ingredient-form")

      html = render_click(view, "set-mode", %{"mode" => "have"})

      assert has_element?(view, "#ingredient-form input[aria-label='Add an ingredient']")
      assert html =~ "in your kitchen"
      refute html =~ "Search recipes"
    end

    test "switching back to Recipes restores the existing search", %{conn: conn} do
      view = have_mode(conn)

      html = render_click(view, "set-mode", %{"mode" => "recipes"})

      assert html =~ "Search recipes"
      refute has_element?(view, "#ingredient-form")
    end

    test "an unknown mode is ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/explore")

      render_click(view, "set-mode", %{"mode" => "admin"})
      html = render_click(view, "set-mode", %{})

      assert html =~ "Search recipes"
      refute has_element?(view, "#ingredient-form")
    end

    test "mode changes are pushed to the SearchPrefs hook", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/explore")
      render_hook(view, "restore-search-prefs", %{"mode" => "recipes", "recent" => ["eggs"]})

      render_click(view, "set-mode", %{"mode" => "have"})
      assert_push_event(view, "search-prefs", %{mode: "have", recent: ["eggs"]})

      add(view, "rice")
      assert_push_event(view, "search-prefs", %{mode: "have", recent: ["rice", "eggs"]})
    end

    test "nothing is pushed before the hook has restored stored prefs", %{conn: conn} do
      # A fresh mount or a rejoin starts from defaults; pushing those would
      # overwrite what the browser stored before the hook sends it back.
      view = have_mode(conn)
      add(view, "rice")

      refute_push_event(view, "search-prefs", %{})
    end
  end

  describe "ingredient chips" do
    test "adding ingredients groups results with missing lists", %{conn: conn, viewer: viewer} do
      cook = user_fixture()
      recipe(viewer, "Lemon rice", ["rice", "lemon"])
      recipe(cook, "Chicken adobo", ["rice", "soy sauce"])

      view = have_mode(conn)
      add(view, "Rice")
      html = add(view, "lemon")

      assert html =~ "You have everything"
      assert html =~ "Lemon rice"
      assert html =~ "Almost there"
      assert html =~ "Chicken adobo"
      assert html =~ "missing: soy sauce"
    end

    test "removing the last chip clears results", %{conn: conn, viewer: viewer} do
      recipe(viewer, "Lemon rice", ["rice"])

      view = have_mode(conn)
      assert add(view, "rice") =~ "You have everything"

      html = render_click(view, "remove-ingredient", %{"ingredient" => "rice"})

      refute html =~ "You have everything"
      refute html =~ "Lemon rice"
      refute has_element?(view, "button[aria-label='Remove rice']")
      assert html =~ "in your kitchen"
    end

    test "an eleventh chip is ignored", %{conn: conn} do
      view = have_mode(conn)
      for i <- 1..11, do: add(view, "item#{i}")

      assert has_element?(view, "button[aria-label='Remove item10']")
      refute has_element?(view, "button[aria-label='Remove item11']")
      assert render(view) =~ "Up to 10 ingredients"
    end

    test "duplicate chips are collapsed case-insensitively", %{conn: conn} do
      view = have_mode(conn)
      add(view, "Rice")
      html = add(view, "  rice ")

      assert length(Regex.scan(~r/aria-label="Remove rice"/, html)) == 1
    end

    test "invalid add-ingredient payloads add no chip", %{conn: conn} do
      view = have_mode(conn)

      render_submit(view, "add-ingredient", %{"ingredient" => ["x"]})
      render_submit(view, "add-ingredient", %{})
      add(view, "   ")
      add(view, String.duplicate("a", 51))
      add(view, "x\u0000y")

      refute has_element?(view, "button[aria-label^='Remove']")
    end

    test "a junk remove-ingredient payload is ignored", %{conn: conn} do
      view = have_mode(conn)
      add(view, "rice")

      render_click(view, "remove-ingredient", %{"ingredient" => %{"a" => 1}})

      assert has_element?(view, "button[aria-label='Remove rice']")
    end

    test "recipes by blocked cooks are excluded", %{conn: conn, viewer: viewer} do
      cook = user_fixture()
      recipe(cook, "Blocked fried rice", ["rice"])
      {:ok, _} = Accounts.block_user(viewer.id, cook.id)

      view = have_mode(conn)
      html = add(view, "rice")

      refute html =~ "Blocked fried rice"
      assert html =~ "No matches yet"
    end
  end

  describe "restore-search-prefs" do
    test "restore-search-prefs reopens the remembered mode", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/explore")

      html = render_hook(view, "restore-search-prefs", %{"mode" => "have", "recent" => ["eggs"]})

      assert has_element?(view, "#ingredient-form")
      assert has_element?(view, "button[phx-value-ingredient='eggs']")
      assert html =~ "Recently used"
    end

    test "a recent chip can be re-added with one click", %{conn: conn, viewer: viewer} do
      recipe(viewer, "Scrambled eggs", ["egg"])
      {:ok, view, _html} = live(conn, ~p"/explore")
      render_hook(view, "restore-search-prefs", %{"mode" => "have", "recent" => ["eggs"]})

      html = view |> element("button[phx-value-ingredient='eggs']") |> render_click()

      assert has_element?(view, "button[aria-label='Remove eggs']")
      assert html =~ "Scrambled eggs"
    end

    test "junk mode and recent values fall back safely", %{conn: conn} do
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
      view = have_mode(conn)
      add(view, "rice")

      render_hook(view, "restore-search-prefs", %{"mode" => "have", "recent" => []})

      assert has_element?(view, "button[aria-label='Remove rice']")
    end
  end
end
