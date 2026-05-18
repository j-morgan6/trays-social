defmodule TraysSocialWeb.WelcomeLive.IndexTest do
  use TraysSocialWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures

  describe "Welcome" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/welcome")
      assert path =~ "/users/log-in"
    end

    test "renders the three-trays intro for a first-run cook", %{conn: conn} do
      user = unfinished_user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/welcome")

      assert html =~ "Welcome, #{user.username}"
      assert html =~ "Three trays"
      assert html =~ "Feed"
      assert html =~ "Find"
      assert html =~ "My Tray"
      assert html =~ "Got it"
    end

    test "redirects to feed if the cook has already seen the welcome", %{conn: conn} do
      # user_fixture stamps seen_welcome_at by default.
      user = user_fixture()

      {:error, {:live_redirect, %{to: path}}} =
        conn
        |> log_in_user(user)
        |> live(~p"/welcome")

      assert path == "/"
    end

    test "continue stamps seen_welcome_at and bounces to the feed", %{conn: conn} do
      user = unfinished_user_fixture()
      assert is_nil(user.seen_welcome_at)

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/welcome")

      {:error, {:live_redirect, %{to: path}}} =
        view
        |> element("button", "Got it")
        |> render_click()

      assert path == "/"

      reloaded = TraysSocial.Repo.reload(user)
      assert reloaded.seen_welcome_at != nil
    end

    test "feed redirects unfinished cooks to /welcome", %{conn: conn} do
      user = unfinished_user_fixture()

      {:error, {:live_redirect, %{to: path}}} =
        conn
        |> log_in_user(user)
        |> live(~p"/")

      assert path == "/welcome"
    end
  end
end
