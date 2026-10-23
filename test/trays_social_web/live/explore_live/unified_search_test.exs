defmodule TraysSocialWeb.ExploreLive.UnifiedSearchTest do
  # async: false: toggles the global :features config.
  use TraysSocialWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  setup %{conn: conn} do
    original = Application.get_env(:trays_social, :features, [])
    on_exit(fn -> Application.put_env(:trays_social, :features, original) end)
    Application.put_env(:trays_social, :features, Keyword.put(original, :recipe_first, true))

    viewer = user_fixture()
    %{conn: log_in_user(conn, viewer), viewer: viewer}
  end

  defp recipe(user, caption, names) do
    ingredients = Enum.map(names, &%{name: &1, quantity: "1", unit: ""})
    post_fixture(%{user_id: user.id, caption: caption, ingredients: ingredients})
  end

  defp type(view, text), do: view |> form("#search-form", %{"query" => text}) |> render_change()
  defp enter(view, text), do: view |> form("#search-form", %{"query" => text}) |> render_submit()

  defp search(conn) do
    {:ok, view, _html} = live(conn, ~p"/search")
    view
  end

  test "one term shows grouped results", %{conn: conn, viewer: viewer} do
    recipe(viewer, "Chicken curry", ["chicken", "curry paste"])
    view = search(conn)

    html = type(view, "chicken")

    assert html =~ "In your tray"
    assert html =~ "Chicken curry"
    refute html =~ "You have everything"
    refute html =~ "Almost there"

    # Committing the term as a chip keeps the same grouped results.
    html = enter(view, "chicken")

    assert has_element?(view, "button[aria-label='Remove chicken']")
    assert html =~ "In your tray"
    refute html =~ "You have everything"
  end

  test "two chips show ingredient results with missing lists", %{conn: conn, viewer: viewer} do
    recipe(viewer, "Chicken rice bowl", ["chicken", "rice"])
    recipe(user_fixture(), "Chicken fried rice", ["chicken", "rice", "soy sauce"])
    view = search(conn)

    enter(view, "chicken")
    html = enter(view, "rice")

    assert html =~ "You have everything"
    assert html =~ "Chicken rice bowl"
    assert html =~ "Almost there"
    assert html =~ "missing: soy sauce"
    refute html =~ "In your tray"
  end

  test "one chip plus typed text counts as two ingredients", %{conn: conn, viewer: viewer} do
    recipe(viewer, "Chicken rice bowl", ["chicken", "rice"])
    view = search(conn)

    enter(view, "chicken")
    html = type(view, "rice")

    assert html =~ "You have everything"
    assert html =~ "Chicken rice bowl"

    # Typing the same ingredient as a chip does not count twice.
    html = type(view, "Chicken")
    refute html =~ "You have everything"
    assert html =~ "In your tray"
  end

  test "removing back to one chip returns to grouped results", %{conn: conn, viewer: viewer} do
    recipe(viewer, "Chicken rice bowl", ["chicken", "rice"])
    view = search(conn)
    enter(view, "chicken")
    assert enter(view, "rice") =~ "You have everything"

    html = render_click(view, "remove-ingredient", %{"ingredient" => "rice"})

    refute html =~ "You have everything"
    assert html =~ "In your tray"
    assert html =~ "Chicken rice bowl"

    html = render_click(view, "remove-ingredient", %{"ingredient" => "chicken"})

    refute html =~ "In your tray"
    assert html =~ "Quick dinners"
  end

  test "an 11th chip is refused and typed text is ignored once full", %{conn: conn} do
    view = search(conn)
    for i <- 1..10, do: enter(view, "item#{i}")

    html = enter(view, "item11")

    refute has_element?(view, "button[aria-label='Remove item11']")
    assert html =~ "Up to 10 ingredients"
    # Still ten terms, so the server accepts the search.
    assert type(view, "item11") =~ "No matches yet"
  end

  test "clearing the search removes chips and returns to Browse", %{conn: conn} do
    view = search(conn)
    enter(view, "chicken")
    enter(view, "rice")

    html = render_click(view, "clear-search", %{})

    refute has_element?(view, "button[aria-label^='Remove']")
    refute html =~ "You have everything"
    assert html =~ "Quick dinners"
  end

  test "a chip replaces a selected Browse tile", %{conn: conn, viewer: viewer} do
    # 90 minutes is outside Quick dinners (max 30), so the recipe only shows
    # once the chip has dropped the tile's filter.
    post_fixture(%{user_id: viewer.id, caption: "Slow tofu stew", cooking_time_minutes: 90})
    view = search(conn)
    render_click(view, "select-category", %{"key" => "quick_dinners"})

    html = render_click(view, "add-ingredient", %{"ingredient" => "tofu"})

    assert has_element?(view, "button[aria-label='Remove tofu']")
    assert html =~ "Slow tofu stew"
  end

  test "blank or invalid submits add no chip", %{conn: conn} do
    view = search(conn)

    enter(view, "   ")
    enter(view, String.duplicate("a", 51))
    render_submit(view, "submit-search", %{"query" => ["x"]})
    render_submit(view, "submit-search", %{})

    refute has_element?(view, "button[aria-label^='Remove']")
  end
end
