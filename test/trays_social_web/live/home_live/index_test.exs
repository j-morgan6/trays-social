defmodule TraysSocialWeb.HomeLive.IndexTest do
  # async: false: toggles the global :features config.
  use TraysSocialWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.MealPlans
  alias TraysSocial.Posts.Post
  alias TraysSocial.Repo

  # Placeholder text unique to the root layout's header search pill (the
  # /explore page field reads "Search recipes, ingredients, cooks…").
  @header_search "Search recipes, cooks, ingredients"

  setup %{conn: conn} do
    original = Application.get_env(:trays_social, :features, [])
    on_exit(fn -> Application.put_env(:trays_social, :features, original) end)
    viewer = user_fixture()
    %{conn: log_in_user(conn, viewer), viewer: viewer, original: original}
  end

  defp flag_on(original),
    do: Application.put_env(:trays_social, :features, Keyword.put(original, :recipe_first, true))

  defp count(html, fragment), do: length(String.split(html, fragment)) - 1

  describe "/home" do
    test "new user sees the welcome block", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/home")

      assert html =~ "Welcome to Trays"
      assert has_element?(view, "#home-welcome a", "Post your first recipe")
      refute has_element?(view, "#home-friends")
      refute has_element?(view, "#home-new")
    end

    test "renders tray, friends, and the finite row", %{conn: conn, viewer: viewer} do
      friend = user_fixture()
      {:ok, _} = Accounts.follow_user(viewer, friend)
      post_fixture(%{user_id: viewer.id, caption: "My chili"})
      post_fixture(%{user_id: friend.id, caption: "Friend focaccia"})

      {:ok, view, _html} = live(conn, ~p"/home")

      refute has_element?(view, "#home-welcome")
      assert has_element?(view, "#home-jump-back-in", "Jump back in")
      assert has_element?(view, "#home-jump-back-in", "My chili")
      assert has_element?(view, "#home-friends", "Friends' trays")
      assert has_element?(view, "#home-friends", friend.username)
      assert has_element?(view, "#home-new", "New from people you follow")
      assert has_element?(view, "#home-new", "Friend focaccia")
      assert has_element?(view, "#home-caught-up", "You're caught up")
    end

    test "the greeting asks the cook by username", %{conn: conn, viewer: viewer} do
      post_fixture(%{user_id: viewer.id, caption: "My chili"})

      {:ok, view, _html} = live(conn, ~p"/home")

      assert has_element?(view, "#home-greeting h1", "What are you cooking, #{viewer.username}?")
    end

    test "a valid tz offset shows the weekday kicker", %{conn: conn, viewer: viewer} do
      post_fixture(%{user_id: viewer.id, caption: "My chili"})

      {:ok, view, _html} = conn |> put_connect_params(%{"tz_offset" => 0}) |> live(~p"/home")

      assert has_element?(
               view,
               "#home-greeting p",
               ~r/^(Mon|Tues|Wednes|Thurs|Fri|Satur|Sun)day (morning|afternoon|evening|night)$/
             )
    end

    test "a missing or invalid tz offset leaves the kicker out", %{conn: conn, viewer: viewer} do
      post_fixture(%{user_id: viewer.id, caption: "My chili"})

      {:ok, missing, _html} = live(conn, ~p"/home")
      refute has_element?(missing, "#home-greeting p")

      {:ok, invalid, _html} =
        conn |> put_connect_params(%{"tz_offset" => 9999}) |> live(~p"/home")

      refute has_element?(invalid, "#home-greeting p")
    end

    test "the welcome block lists cooks to follow as profile links, with no Follow button", %{
      conn: conn
    } do
      cook = user_fixture()
      post_fixture(%{user_id: cook.id, caption: "Cook pie"})

      {:ok, view, _html} = live(conn, ~p"/home")

      assert has_element?(view, "#home-cooks", "Cooks to follow")
      assert has_element?(view, ~s(#home-cooks a[href="/@#{cook.username}"]), cook.username)
      refute has_element?(view, "#home-cooks button")
    end

    test "new recipes carry the New badge and the cook time", %{conn: conn, viewer: viewer} do
      friend = user_fixture()
      {:ok, _} = Accounts.follow_user(viewer, friend)
      post_fixture(%{user_id: friend.id, caption: "Friend focaccia", cooking_time_minutes: 90})

      {:ok, view, _html} = live(conn, ~p"/home")

      assert has_element?(view, "#home-new span.bg-accent", "New")
      assert has_element?(view, "#home-new", "1 hr 30 min")
      assert has_element?(view, "#home-new", "Just now")
    end

    test "today's planned recipe shows as the Tonight strip", %{conn: conn, viewer: viewer} do
      post = post_fixture(%{user_id: viewer.id, caption: "Sheet-pan gnocchi"})
      {:ok, _entry} = MealPlans.create_entry(viewer, Date.utc_today(), post)

      {:ok, view, _html} = live(conn, ~p"/home")

      assert has_element?(view, "#home-tonight", "Tonight")
      assert has_element?(view, "#home-tonight", "Sheet-pan gnocchi")
    end

    test "the dead render shows the loading skeleton", %{conn: conn} do
      html = conn |> get(~p"/home") |> html_response(200)

      assert html =~ ~s(id="home-loading")
    end

    test "a followed cook with nothing from the last week shows Nothing new", %{
      conn: conn,
      viewer: viewer
    } do
      friend = user_fixture()
      {:ok, _} = Accounts.follow_user(viewer, friend)
      old = post_fixture(%{user_id: friend.id, caption: "Old stew"})
      eight_days_ago = :second |> DateTime.utc_now() |> DateTime.add(-8, :day)
      old_post = from(p in Post, where: p.id == ^old.id)
      Repo.update_all(old_post, set: [inserted_at: eight_days_ago])

      {:ok, view, _html} = live(conn, ~p"/home")

      assert has_element?(view, "#home-caught-up", "Nothing new this week")
    end

    test "phone-first layout: two-column grid and rows that scroll on their own", %{
      conn: conn,
      viewer: viewer
    } do
      friend = user_fixture()
      {:ok, _} = Accounts.follow_user(viewer, friend)
      post_fixture(%{user_id: viewer.id, caption: "My chili"})
      post_fixture(%{user_id: friend.id, caption: "Friend focaccia"})

      {:ok, view, _html} = live(conn, ~p"/home")

      assert has_element?(view, "#home-jump-back-in div.grid-cols-2")
      assert has_element?(view, "#home-friends div.overflow-x-auto")
      assert has_element?(view, "#home-new div.overflow-x-auto")
    end

    test "long usernames wrap or truncate instead of overflowing", %{conn: conn} do
      long = String.duplicate("a", 30)
      viewer = user_fixture(%{username: long})
      cook = user_fixture(%{username: String.duplicate("b", 30)})
      post_fixture(%{user_id: cook.id, caption: "Cook pie"})
      conn = log_in_user(conn, viewer)

      {:ok, welcome_view, _html} = live(conn, ~p"/home")
      assert has_element?(welcome_view, "#home-cooks span.truncate", cook.username)

      {:ok, _} = Accounts.follow_user(viewer, cook)
      post_fixture(%{user_id: viewer.id, caption: "My chili"})

      {:ok, view, _html} = live(conn, ~p"/home")

      assert has_element?(view, ~s(#home-greeting h1[class*="overflow-wrap:anywhere"]), long)
      assert has_element?(view, "#home-friends span.truncate", cook.username)
    end

    test "guests are sent to log in" do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(build_conn(), ~p"/home")
    end
  end

  describe "redirects" do
    test "flag on: /feed redirects to /home", %{conn: conn, original: original} do
      flag_on(original)
      assert {:error, {:live_redirect, %{to: "/home"}}} = live(conn, ~p"/feed")
    end

    test "flag on: an unfinished cook still sees /welcome first", %{original: original} do
      flag_on(original)
      conn = log_in_user(build_conn(), unfinished_user_fixture())
      assert {:error, {:live_redirect, %{to: "/welcome"}}} = live(conn, ~p"/feed")
    end

    test "flag off: /feed still renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/feed")

      assert html =~ ~s(href="/feed")
      refute html =~ ~s(href="/home")
    end

    test "flag on: / sends logged-in users to /home", %{conn: conn, original: original} do
      flag_on(original)
      assert redirected_to(get(conn, ~p"/")) == "/home"
    end

    test "flag off: / sends logged-in users to /feed", %{conn: conn} do
      assert redirected_to(get(conn, ~p"/")) == "/feed"
    end

    test "flag on: sign-in lands on /home", %{viewer: viewer, original: original} do
      flag_on(original)
      viewer = set_password(viewer)

      conn =
        post(build_conn(), ~p"/users/log-in", %{
          "user" => %{"email" => viewer.email, "password" => valid_user_password()}
        })

      assert redirected_to(conn) == "/home"
    end

    test "flag on: signed-in visitors to guest pages go to /home", %{
      conn: conn,
      original: original
    } do
      flag_on(original)
      assert redirected_to(get(conn, ~p"/users/register")) == "/home"
    end
  end

  describe "nav" do
    test "flag on: nav shows Home and Search", %{conn: conn, original: original} do
      flag_on(original)
      html = conn |> get(~p"/home") |> html_response(200)

      # Desktop and mobile each link Home, Search and My Tray; the header
      # search pill is gone, so the Search tabs are the only /search links.
      assert count(html, ~s(href="/home")) == 2
      assert count(html, ~s(href="/search")) == 2
      assert count(html, ~s(href="/my-tray")) == 2
      assert html =~ "<span>Home</span>"
      assert html =~ "<span>Search</span>"
      assert html =~ "<span>My Tray</span>"
      refute html =~ ~s(href="/feed")
      refute html =~ ~s(href="/explore")
      refute html =~ "<span>Feed</span>"
      refute html =~ "<span>Profile</span>"
    end

    test "flag off: nav keeps Feed, Find and Explore", %{conn: conn} do
      html = conn |> get(~p"/home") |> html_response(200)

      assert count(html, ~s(href="/feed")) == 2
      assert count(html, ~s(href="/explore")) == 3
      assert count(html, ~s(href="/my-tray")) == 1
      assert html =~ "<span>Feed</span>"
      assert html =~ "<span>Profile</span>"
      assert html =~ ~s(<span class="hero-user w-6 h-6"></span>)
      refute html =~ ~s(href="/home")
      refute html =~ ~s(href="/search")
    end

    test "flag on: guest nav is unchanged", %{original: original} do
      flag_on(original)
      html = build_conn() |> get(~p"/users/log-in") |> html_response(200)

      assert html =~ ~s(href="/feed")
      assert html =~ ~s(href="/explore")
      assert html =~ @header_search
      refute html =~ ~s(href="/home")
      refute html =~ ~s(href="/search")
    end

    test "flag on: header search box is not rendered", %{conn: conn, original: original} do
      flag_on(original)
      html = conn |> get(~p"/home") |> html_response(200)

      refute html =~ @header_search
      # The Search tab stays reachable on desktop and mobile.
      assert count(html, ~s(href="/search")) == 2
      assert html =~ "<span>Search</span>"
    end

    test "flag off: header search box still renders", %{conn: conn} do
      html = conn |> get(~p"/home") |> html_response(200)

      assert count(html, @header_search) == 1
      assert html =~ ~r{href="/explore"[^>]*rounded-full}
    end
  end
end
