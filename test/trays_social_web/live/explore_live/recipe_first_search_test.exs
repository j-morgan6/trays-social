defmodule TraysSocialWeb.ExploreLive.RecipeFirstSearchTest do
  # async: false: toggles the global :features config.
  use TraysSocialWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.Repo

  setup %{conn: conn} do
    original = Application.get_env(:trays_social, :features, [])
    on_exit(fn -> Application.put_env(:trays_social, :features, original) end)
    viewer = user_fixture()
    %{conn: log_in_user(conn, viewer), viewer: viewer, original: original}
  end

  defp flag_on(original),
    do: Application.put_env(:trays_social, :features, Keyword.put(original, :recipe_first, true))

  test "flag off: /explore renders as today", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/explore")

    assert html =~ "Search recipes"
    assert html =~ "Under 30 min"
    refute html =~ "Most saved this week"
    refute html =~ "Quick dinners"
  end

  test "flag on: /explore redirects to /search", %{conn: conn, original: original} do
    flag_on(original)
    assert {:error, {:live_redirect, %{to: "/search"}}} = live(conn, ~p"/explore")
  end

  test "flag on: browse tiles and most saved before typing", %{
    conn: conn,
    viewer: viewer,
    original: original
  } do
    flag_on(original)
    post_fixture(%{user_id: viewer.id, caption: "Weeknight pho"})

    {:ok, _view, html} = live(conn, ~p"/search")

    assert html =~ "Quick dinners"
    assert html =~ "Most saved this week"
    assert html =~ "Weeknight pho"
    refute html =~ "Under 30 min"
  end

  test "flag on: typing shows grouped results", %{conn: conn, viewer: viewer, original: original} do
    flag_on(original)
    friend = user_fixture()
    {:ok, _} = Accounts.follow_user(viewer, friend)
    post_fixture(%{user_id: viewer.id, caption: "Fish taco"})
    post_fixture(%{user_id: friend.id, caption: "Birria taco"})
    post_fixture(%{user_id: user_fixture().id, caption: "Taco salad"})

    {:ok, view, _html} = live(conn, ~p"/search")
    html = view |> element("form[phx-change=search]") |> render_change(%{"query" => "taco"})

    assert html =~ "In your tray"
    assert html =~ "Fish taco"
    assert html =~ "From people you follow"
    assert html =~ "Birria taco"
    assert html =~ "Everyone"
    assert html =~ "Taco salad"
    refute html =~ "Most saved this week"

    html = render_click(view, "clear-search", %{})

    assert html =~ "Quick dinners"
    refute html =~ "In your tray"

    # Emptying the query by hand also returns to Browse.
    view |> element("form[phx-change=search]") |> render_change(%{"query" => "taco"})
    html = view |> element("form[phx-change=search]") |> render_change(%{"query" => ""})

    assert html =~ "Quick dinners"
    refute html =~ "In your tray"
  end

  test "flag on: a category tile runs its query", %{
    conn: conn,
    viewer: viewer,
    original: original
  } do
    flag_on(original)
    post_fixture(%{user_id: viewer.id, caption: "Ten minute eggs", cooking_time_minutes: 10})
    post_fixture(%{user_id: viewer.id, caption: "Slow braise", cooking_time_minutes: 240})
    post_fixture(%{user_id: viewer.id, caption: "Lemon chicken", cooking_time_minutes: 60})

    {:ok, view, _html} = live(conn, ~p"/search")

    # An unknown key, or no key at all, is ignored: still Browse, no crash.
    html = render_click(view, "select-category", %{"key" => "bogus"})
    assert html =~ "Quick dinners"
    refute html =~ "In your tray"

    html = render_click(view, "select-category", %{})
    assert html =~ "Quick dinners"
    refute html =~ "In your tray"

    html =
      view
      |> element("button[phx-value-key=quick_dinners]")
      |> render_click()

    assert html =~ "Ten minute eggs"
    refute html =~ "Slow braise"

    # An unknown key after a tile keeps that tile's results.
    html = render_click(view, "select-category", %{"key" => "bogus"})
    assert html =~ "Ten minute eggs"
    refute html =~ "Slow braise"

    # A query-based tile searches its saved term.
    html = render_click(view, "select-category", %{"key" => "chicken"})
    assert html =~ "Lemon chicken"
    refute html =~ "Ten minute eggs"

    # Typing replaces the tile: its filter no longer applies.
    render_click(view, "select-category", %{"key" => "quick_dinners"})
    html = view |> element("form[phx-change=search]") |> render_change(%{"query" => "braise"})
    assert html =~ "Slow braise"
  end

  # A recent, liked, tagged post: each classic rail query (trending, recent,
  # tag sections) returns it, so an empty assign can only mean the query was
  # skipped.
  defp classic_rail_post(user) do
    %{user_id: user.id, caption: "Rail stew", post_tags: [%{tag: "stew"}]}
    |> post_fixture()
    |> Ecto.Changeset.change(%{like_count: 5})
    |> Repo.update!()
  end

  test "flag on: classic trending, recent and tag rails are not loaded", %{
    conn: conn,
    viewer: viewer,
    original: original
  } do
    flag_on(original)
    classic_rail_post(viewer)

    {:ok, view, html} = live(conn, ~p"/search")

    assigns = :sys.get_state(view.pid).socket.assigns
    assert assigns.trending == []
    assert assigns.recent == []
    assert assigns.tag_sections == []

    # Browse still renders, so the empty rails did not break the page.
    assert html =~ "Most saved this week"
    assert html =~ "Rail stew"
  end

  test "flag off: /explore still renders trending and tag rails", %{conn: conn, viewer: viewer} do
    classic_rail_post(viewer)

    {:ok, view, html} = live(conn, ~p"/explore")

    assert html =~ "Popular this week"
    assert html =~ "New on Trays"
    assert html =~ "Stew"
    assert html =~ "Rail stew"

    assigns = :sys.get_state(view.pid).socket.assigns
    assert [%{caption: "Rail stew"}] = assigns.trending
    assert [%{caption: "Rail stew"}] = assigns.recent
    assert [{"stew", [%{caption: "Rail stew"}]}] = assigns.tag_sections
  end

  # The flag is read once at mount: flipping it under a connected socket must
  # not switch the branch or the rail assigns until the next mount.
  test "flag flipped while connected: each socket keeps its mount-time branch", %{
    conn: conn,
    viewer: viewer,
    original: original
  } do
    classic_rail_post(viewer)

    flag_on(original)
    {:ok, search_view, _html} = live(conn, ~p"/search")
    Application.put_env(:trays_social, :features, original)

    html = render_click(search_view, "clear-search", %{})
    assert html =~ "Quick dinners"
    refute html =~ "Popular this week"
    assigns = :sys.get_state(search_view.pid).socket.assigns
    assert assigns.recipe_first
    assert {assigns.trending, assigns.recent, assigns.tag_sections} == {[], [], []}

    {:ok, explore_view, _html} = live(conn, ~p"/explore")
    flag_on(original)

    html = render_click(explore_view, "clear-search", %{})
    assert html =~ "Popular this week"
    refute html =~ "Quick dinners"
    assigns = :sys.get_state(explore_view.pid).socket.assigns
    refute assigns.recipe_first
    assert [%{caption: "Rail stew"}] = assigns.trending
  end
end
