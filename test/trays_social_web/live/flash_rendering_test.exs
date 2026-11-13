defmodule TraysSocialWeb.FlashRenderingTest do
  @moduledoc """
  D127: LiveView never re-renders the root layout, so a flash group there
  only showed flashes that arrived with a full page load. Every LiveView now
  renders its own group through `Layouts.live/1`, and the root layout skips
  its group when it wraps a LiveView, so the first render shows one group.

  `live/2` returns the LiveView's own render, without the root layout, so a
  `#flash-*` element found through `has_element?/3` came from the live
  layout. Dead renders (`get/2`) include the root layout and are counted.
  """
  use TraysSocialWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.Reports

  defp count(html, selector) do
    html |> LazyHTML.from_document() |> LazyHTML.query(selector) |> Enum.count()
  end

  describe "LiveView flashes show without a page load" do
    test "an admin suspend action's put_flash shows in ReportsLive without navigation",
         %{conn: conn} do
      {:ok, admin} = Accounts.set_admin(user_fixture(), true)
      target = user_fixture()

      {:ok, report} =
        Reports.create_report(user_fixture(), %{
          target_type: "user",
          target_id: target.id,
          reason: "spam"
        })

      {:ok, view, _html} = conn |> log_in_user(admin) |> live(~p"/admin/reports")
      refute has_element?(view, "#flash-info")

      render_submit(view, "suspend_user", %{
        "report_id" => to_string(report.id),
        "suspended_until" => ""
      })

      assert has_element?(view, "#flash-info", "User suspended indefinitely.")
    end

    test "a failed comment on PostLive.Show shows its error flash", %{conn: conn} do
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/posts/#{post.id}")
      refute has_element?(view, "#flash-error")

      # Comment bodies are capped at 1000 characters, so this one fails.
      render_click(view, "add-comment", %{"comment" => %{"body" => String.duplicate("a", 1001)}})

      assert has_element?(view, "#flash-error", "Could not add comment")
    end

    test "Profile not found flash survives push_navigate to /feed", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      {:ok, view, _html} =
        conn
        |> live(~p"/@nonexistentuser")
        |> follow_redirect(conn, ~p"/feed")

      assert has_element?(view, "#flash-error", "User not found")
    end

    test "Cook not found flash survives push_navigate from FollowersLive.Show to /feed",
         %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      {:ok, view, _html} =
        conn
        |> live(~p"/@nonexistentuser/followers")
        |> follow_redirect(conn, ~p"/feed")

      assert has_element?(view, "#flash-error", "Cook not found")
    end

    test "an email-change flash in SettingsLive.Index shows without navigation", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/users/settings")
      refute has_element?(view, "#flash-info")

      new_email = "flash#{System.unique_integer([:positive])}@example.com"

      view
      |> element("#email-form")
      |> render_submit(%{
        "user" => %{"email" => new_email, "current_password" => valid_user_password()}
      })

      assert has_element?(view, "#flash-info", "A link to confirm your email change")
    end

    test "the toast stays dismissible after live navigation", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      {:ok, view, _html} =
        conn
        |> live(~p"/@nonexistentuser")
        |> follow_redirect(conn, ~p"/feed")

      view |> element("#flash-error") |> render_click()

      refute has_element?(view, "#flash-error")
    end

    test "a page with no flash renders an empty flash group", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/@#{user.username}")

      assert has_element?(view, "#flash-group")
      refute has_element?(view, "#flash-info")
      refute has_element?(view, "#flash-error")
    end
  end

  describe "dead render" do
    test "the dead render of a LiveView shows exactly one flash group", %{conn: conn} do
      user = user_fixture()
      html = conn |> log_in_user(user) |> get(~p"/@#{user.username}") |> html_response(200)

      assert count(html, "#flash-group") == 1
      assert count(html, "#client-error") == 1
      # The one group is the live layout's, inside the LiveView container.
      assert count(html, "[data-phx-main] #flash-group") == 1
    end

    test "a flash set by a controller redirect into a LiveView shows once", %{conn: conn} do
      user = user_fixture()

      conn =
        post(conn, ~p"/users/log-in?mode=password", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      html = conn |> recycle() |> get(redirected_to(conn)) |> html_response(200)

      assert count(html, "#flash-group") == 1
      assert count(html, "#flash-info") == 1
      assert html =~ "Welcome back!"
    end
  end

  describe "PostLive.New" do
    test "PostLive.New shows its save error inline only, not also as a toast", %{conn: conn} do
      {:ok, view, _html} = conn |> log_in_user(user_fixture()) |> live(~p"/posts/new")

      # With recipe-first off the editor opens on the type picker; with it
      # on, the form is already there and the event is a no-op re-init.
      render_click(view, "select-type", %{"type" => "recipe"})

      view |> element("form#post-form") |> render_submit(%{post: %{caption: ""}})

      assert has_element?(view, "#editor-form-note", "Please upload at least one photo")
      refute has_element?(view, "#flash-error")
      assert has_element?(view, "#flash-group")
    end
  end
end
