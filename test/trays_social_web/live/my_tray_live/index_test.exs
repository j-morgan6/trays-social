defmodule TraysSocialWeb.MyTrayLive.IndexTest do
  use TraysSocialWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Posts

  describe "My Tray" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/my-tray")
      assert path =~ "/users/log-in"
    end

    test "renders the My Tray header for an authenticated user", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my-tray")

      assert html =~ "My Tray"
      assert html =~ "All saved"
    end

    test "shows the empty state when nothing is saved", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my-tray")

      html = render(view)
      assert html =~ "Nothing saved yet"
      assert html =~ "Find recipes to save"
    end

    test "renders saved recipes as cards", %{conn: conn} do
      user = user_fixture()
      author = user_fixture()
      post = post_fixture(user_id: author.id, caption: "Sunday short ribs over polenta")
      {:ok, _bookmark} = Posts.create_bookmark(user.id, post.id)

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my-tray")

      html = render(view)
      # Title (derived from caption first sentence) and author username
      # both surface on the saved card.
      assert html =~ "Sunday short ribs over polenta"
      assert html =~ author.username
      # Saved-date chip is present.
      assert html =~ "Saved "
    end
  end
end
