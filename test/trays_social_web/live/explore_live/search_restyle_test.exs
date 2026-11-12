defmodule TraysSocialWeb.ExploreLive.SearchRestyleTest do
  # W244: the restyled web Search (recipe-first). async: false because it
  # toggles the global :features config.
  use TraysSocialWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Accounts

  setup %{conn: conn} do
    original = Application.get_env(:trays_social, :features, [])
    on_exit(fn -> Application.put_env(:trays_social, :features, original) end)
    put_features(original, web_ads: false)

    viewer = user_fixture()
    %{conn: log_in_user(conn, viewer), viewer: viewer, original: original}
  end

  defp put_features(original, extra) do
    features = original |> Keyword.put(:recipe_first, true) |> Keyword.merge(extra)
    Application.put_env(:trays_social, :features, features)
  end

  defp recipe(user, caption, names \\ ["test ingredient"]) do
    ingredients = Enum.map(names, &%{name: &1, quantity: "1", unit: ""})
    post_fixture(%{user_id: user.id, caption: caption, ingredients: ingredients})
  end

  defp search(conn) do
    {:ok, view, _html} = live(conn, ~p"/search")
    view
  end

  defp type(view, text), do: view |> form("#search-form", %{"query" => text}) |> render_change()
  defp enter(view, text), do: view |> form("#search-form", %{"query" => text}) |> render_submit()

  defp slot_count(html), do: length(String.split(html, "data-ad-slot=")) - 1

  describe "Browse" do
    test "six category tiles cycle cream, amber and mint fills", %{conn: conn} do
      view = search(conn)

      assert has_element?(view, "#search-browse h2", "Browse")
      assert has_element?(view, "#search-browse button[phx-value-key]:nth-child(1).bg-cream-lift")

      assert has_element?(
               view,
               "#search-browse button[phx-value-key]:nth-child(2).bg-accent\\/25"
             )

      assert has_element?(view, "#search-browse button[phx-value-key]:nth-child(3).bg-mint-tint")
      assert has_element?(view, "#search-browse button[phx-value-key]:nth-child(4).bg-cream-lift")
      refute has_element?(view, "#search-browse button[phx-value-key]:nth-child(7)")
    end

    test "Most saved ranks its first three recipes", %{conn: conn} do
      cook = user_fixture()
      for n <- 1..4, do: recipe(cook, "Saved dish #{n}")
      view = search(conn)

      assert has_element?(view, "#search-most-saved span", "#1")
      assert has_element?(view, "#search-most-saved span", "#3")
      refute has_element?(view, "#search-most-saved span", "#4")
    end

    test "the dead render shows a link-free loading skeleton", %{conn: conn} do
      html = conn |> get(~p"/search") |> html_response(200)

      assert html =~ ~s(id="search-loading")
      assert html =~ "animate-pulse"
      refute html =~ ~s(id="search-most-saved")
    end
  end

  describe "grouped results" do
    test "cooks are profile links with no follow button", %{conn: conn} do
      user_fixture(%{username: "tacochef"})
      view = search(conn)
      type(view, "taco")

      assert has_element?(view, "#search-cooks a[href='/@tacochef']", "@tacochef")
      refute has_element?(view, "#search-cooks button")
    end

    test "a blocked cook never appears in the Cooks panel", %{conn: conn, viewer: viewer} do
      user_fixture(%{username: "tacoopen"})
      blocked = user_fixture(%{username: "tacoblocked"})
      {:ok, _} = Accounts.block_user(viewer.id, blocked.id)
      view = search(conn)
      type(view, "taco")

      assert has_element?(view, "#search-cooks a[href='/@tacoopen']")
      refute has_element?(view, "#search-cooks a[href='/@tacoblocked']")
    end

    test "a text Browse tile searches cooks by its query; a tag tile shows none", %{conn: conn} do
      user_fixture(%{username: "chickenchef"})
      user_fixture(%{username: "breakfastcook"})
      view = search(conn)

      render_click(view, "select-category", %{"key" => "chicken"})
      assert has_element?(view, "#search-cooks a[href='/@chickenchef']")

      html = render_click(view, "select-category", %{"key" => "breakfast"})
      refute html =~ ~s(id="search-cooks")
    end

    test "tray rows are row cards with the cook time", %{conn: conn, viewer: viewer} do
      post = recipe(viewer, "Pan curry")
      view = search(conn)
      type(view, "curry")

      assert has_element?(view, "#search-tray h2", "In your tray")
      assert has_element?(view, "#search-tray a[href='/posts/#{post.id}']", "42 min")
    end

    test "no results uses the plain empty block", %{conn: conn} do
      view = search(conn)
      html = type(view, "zzzqqq")

      assert html =~ "No results yet."
      assert html =~ "Try a different recipe, ingredient, or cook."
      refute has_element?(view, ".bg-cream-lift.rounded-3xl")
    end
  end

  describe "ingredient results" do
    test "the summary card and the ready and need rows", %{conn: conn, viewer: viewer} do
      recipe(viewer, "Chicken rice bowl", ["chicken thighs", "rice"])
      recipe(user_fixture(), "Chicken fried rice", ["chicken", "rice", "soy sauce"])
      view = search(conn)
      enter(view, "chicken")
      enter(view, "rice")

      assert has_element?(view, "#ingredient-summary h2", "With chicken and rice, you can make…")
      assert has_element?(view, "#ingredient-summary p", "1 ready now · 1 almost there")
      assert has_element?(view, "#ingredient-everything", "Ready to cook")
      assert has_element?(view, "#ingredient-everything", "Uses chicken, rice")
      assert has_element?(view, "#ingredient-almost", "Need 1")
      assert render(view) =~ "count as pantry staples"
    end

    test "no ingredient matches uses the plain empty block", %{conn: conn} do
      view = search(conn)
      enter(view, "zzzqqq")
      html = enter(view, "yyyppp")

      assert html =~ "No matches yet."
      assert html =~ "Try removing an ingredient."
      refute has_element?(view, "#ingredient-summary")
    end
  end

  describe "state e (loading)" do
    test "the form keeps its search event and the term skeleton waits behind it", %{conn: conn} do
      view = search(conn)

      assert has_element?(view, "form#search-form[phx-change=search][phx-submit=submit-search]")

      assert has_element?(
               view,
               "#search-results #search-results-loading.hidden.search-loading\\:block"
             )

      assert has_element?(view, "#search-results-loading-term")
      refute has_element?(view, "#search-results-loading a")
      assert has_element?(view, "#search-results #search-results-content.search-loading\\:hidden")
    end

    test "two ingredients switch the skeleton to the ingredient shape", %{conn: conn} do
      view = search(conn)
      enter(view, "chicken")
      enter(view, "rice")

      assert has_element?(view, "#search-results-loading-ingredients")
      refute has_element?(view, "#search-results-loading-term")
    end
  end

  describe "narrow width" do
    test "grids start at two columns and the page has no sideways scroller", %{
      conn: conn,
      viewer: viewer
    } do
      cook = user_fixture(%{username: "stewcook"})
      for n <- 1..3, do: recipe(cook, "Stew dish #{n}")
      recipe(viewer, "My stew")
      view = search(conn)

      assert has_element?(view, "#search-browse .grid.grid-cols-2")
      assert has_element?(view, "#search-most-saved .grid.grid-cols-2")

      html = type(view, "stew")

      assert has_element?(view, "#search-everyone .grid.grid-cols-2")
      assert has_element?(view, "#search-cooks .grid:not([class*='grid-cols-2'])")
      refute html =~ "overflow-x"
    end
  end

  describe "long names" do
    test "long titles clamp and a 30-character username truncates", %{
      conn: conn,
      viewer: viewer
    } do
      long_name = String.pad_trailing("braisecook", 30, "x")
      cook = user_fixture(%{username: long_name})
      long_title = "Braise " <> String.duplicate("slowly with onions and stock ", 4)
      recipe(cook, long_title)
      recipe(viewer, long_title)
      view = search(conn)
      type(view, "braise")

      assert has_element?(view, "#search-cooks a span.min-w-0.truncate", "@" <> long_name)
      assert has_element?(view, "#search-everyone h3.line-clamp-2")
      assert has_element?(view, "#search-tray .min-w-0 h3.truncate")
    end
  end

  describe "sponsored cards" do
    test "one in Most saved with nine recipes when web ads are on", %{
      conn: conn,
      original: original
    } do
      put_features(original, web_ads: true)
      cook = user_fixture()
      for n <- 1..9, do: recipe(cook, "Ad dish #{n}")

      {:ok, view, _html} = live(conn, ~p"/search")

      assert slot_count(render(view)) == 1
      assert has_element?(view, "#search-most-saved [data-ad-slot='find-0']", "Sponsored")

      assert has_element?(
               view,
               "#search-most-saved a[href='/privacy/ads-choices']",
               "Why this ad?"
             )
    end

    test "none with web ads off", %{conn: conn} do
      cook = user_fixture()
      for n <- 1..9, do: recipe(cook, "Plain dish #{n}")

      assert conn |> search() |> render() |> slot_count() == 0
    end

    test "none for a subscriber", %{conn: conn, original: original} do
      put_features(original, web_ads: true)
      subscriber = user_fixture()
      {:ok, subscriber} = Accounts.set_subscriber(subscriber, true)
      cook = user_fixture()
      for n <- 1..9, do: recipe(cook, "Paid dish #{n}")

      html = conn |> log_in_user(subscriber) |> search() |> render()

      assert slot_count(html) == 0
    end

    test "two in Everyone with 17 recipes, none in tray or following", %{
      conn: conn,
      viewer: viewer,
      original: original
    } do
      put_features(original, web_ads: true)
      friend = user_fixture()
      {:ok, _} = Accounts.follow_user(viewer, friend)
      stranger = user_fixture()
      for n <- 1..17, do: recipe(stranger, "Stew number #{n}")
      for n <- 1..5, do: recipe(viewer, "My stew #{n}")
      for n <- 1..5, do: recipe(friend, "Friend stew #{n}")
      view = search(conn)
      html = type(view, "stew")

      assert slot_count(html) == 2
      assert has_element?(view, "#search-everyone [data-ad-slot='find-1']")
      refute has_element?(view, "#search-tray [data-ad-slot]")
      refute has_element?(view, "#search-following [data-ad-slot]")
    end
  end

  describe "classic Find while a search is in flight" do
    test "keeps its results visible: no skeleton swap when the recipe-first flag is off", %{
      conn: conn,
      original: original
    } do
      Application.put_env(:trays_social, :features, Keyword.put(original, :recipe_first, false))
      {:ok, view, _html} = live(conn, ~p"/explore")

      assert has_element?(view, "#search-results-content")
      refute has_element?(view, "#search-results-content.search-loading\\:hidden")
      refute has_element?(view, "#search-results-loading")
    end
  end
end
