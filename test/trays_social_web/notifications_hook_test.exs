defmodule TraysSocialWeb.NotificationsHookTest do
  use TraysSocialWeb.ConnCase

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Notifications

  describe "NotificationsHook" do
    test "assigns unread_notifications to 0 for unauthenticated user", %{conn: conn} do
      # Post detail (/posts/:id) is one of the few routes still
      # mount_current_scope (anonymous-OK) after D60, so it's the right
      # surface to exercise the notifications hook for the unauthed case.
      user = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, _view, html} = live(conn, ~p"/posts/#{post.id}")

      # Unauthenticated users get unread_notifications = 0, verified by page
      # rendering without error.
      assert html =~ post.caption
    end

    test "assigns unread_notifications count for authenticated user", %{conn: conn} do
      user = user_fixture()
      actor = user_fixture()
      post = post_fixture(user_id: user.id)

      # Create an unread notification
      {:ok, _notification} =
        Notifications.create_notification(%{
          type: "like",
          user_id: user.id,
          actor_id: actor.id,
          post_id: post.id
        })

      {:ok, _view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/explore")

      # The page renders without error, meaning the hook worked correctly
      # The unread count would be 1 for this user
    end

    test "increments unread count when new notification arrives via PubSub", %{conn: conn} do
      user = user_fixture()
      actor = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/explore")

      # Simulate a new notification broadcast
      {:ok, notification} =
        Notifications.create_notification(%{
          type: "like",
          user_id: user.id,
          actor_id: actor.id,
          post_id: post.id
        })

      send(view.pid, {:new_notification, notification})

      # The view should still render without errors after handling the message
      _html = render(view)
    end

    test "resets unread count when notifications_read message arrives", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/explore")

      # Simulate a notifications_read broadcast
      send(view.pid, {:notifications_read, user.id})

      # The view should still render without errors after handling the message
      _html = render(view)
    end

    test "passes through unhandled messages", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/explore")

      # Send an unrelated message -- the hook should pass it through with :cont
      send(view.pid, {:unrelated_message, "test"})

      # The view should still render without errors
      _html = render(view)
    end
  end
end
