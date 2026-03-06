defmodule TraysSocialWeb.NotificationsLive.IndexTest do
  use TraysSocialWeb.ConnCase

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Notifications

  describe "Notifications page" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/notifications")
    end

    test "renders the notifications page for authenticated user", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/notifications")

      assert html =~ "Notifications"
    end

    test "displays like notification", %{conn: conn} do
      user = user_fixture()
      actor = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, _notification} =
        Notifications.create_notification(%{
          type: "like",
          user_id: user.id,
          actor_id: actor.id,
          post_id: post.id
        })

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/notifications")

      assert html =~ actor.username
      assert html =~ "liked your post"
    end

    test "displays comment notification", %{conn: conn} do
      user = user_fixture()
      actor = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, _notification} =
        Notifications.create_notification(%{
          type: "comment",
          user_id: user.id,
          actor_id: actor.id,
          post_id: post.id
        })

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/notifications")

      assert html =~ actor.username
      assert html =~ "commented on your post"
    end

    test "displays follow notification", %{conn: conn} do
      user = user_fixture()
      actor = user_fixture()

      {:ok, _notification} =
        Notifications.create_notification(%{
          type: "follow",
          user_id: user.id,
          actor_id: actor.id
        })

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/notifications")

      assert html =~ actor.username
      assert html =~ "started following you"
    end

    test "shows empty notifications list when none exist", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/notifications")

      assert html =~ "Notifications"
      # The notifications stream container should be present but empty
      assert html =~ "notifications"
    end

    test "handles new notification message via PubSub without crashing", %{conn: conn} do
      user = user_fixture()
      actor = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/notifications")

      # Create a notification which broadcasts via PubSub
      {:ok, notification} =
        Notifications.create_notification(%{
          type: "like",
          user_id: user.id,
          actor_id: actor.id,
          post_id: post.id
        })

      # Send the notification message directly to the LiveView process
      # This exercises handle_info({:new_notification, notification}, socket)
      send(view.pid, {:new_notification, notification})

      # Verify the view still renders without error after receiving the message
      assert render(view) =~ "Notifications"
    end

    test "new follow notification via handle_info does not crash", %{conn: conn} do
      user = user_fixture()
      actor = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/notifications")

      {:ok, notification} =
        Notifications.create_notification(%{
          type: "follow",
          user_id: user.id,
          actor_id: actor.id
        })

      send(view.pid, {:new_notification, notification})

      # Verify the view still renders without error
      assert render(view) =~ "Notifications"
    end

    test "handle_info with unknown message does not crash", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/notifications")

      # Send an unrecognized message to exercise the catch-all handle_info
      send(view.pid, {:unknown_message, "some data"})

      # The view should still be alive and render properly
      assert render(view) =~ "Notifications"
    end

    test "marks all notifications as read on mount", %{conn: conn} do
      user = user_fixture()
      actor = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, _notification} =
        Notifications.create_notification(%{
          type: "like",
          user_id: user.id,
          actor_id: actor.id,
          post_id: post.id
        })

      # Visiting the notifications page should mark them as read
      {:ok, _view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/notifications")

      # After mount, the notification should now be read
      notifications = Notifications.list_notifications(user.id)
      assert Enum.all?(notifications, fn n -> n.read_at != nil end)
    end

    test "handle_info with multiple unknown messages does not crash", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/notifications")

      # Send several different unrecognized messages
      send(view.pid, :tick)
      send(view.pid, {:some_event, %{data: "test"}})
      send(view.pid, "plain string message")

      :timer.sleep(100)

      # The view should still be alive and render properly
      html = render(view)
      assert html =~ "Notifications"
    end
  end
end
