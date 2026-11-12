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

      # Editorial heading on the page is "Notes for you"; the page title
      # (window/tab) still says "Notifications".
      assert html =~ "Notes for you"
    end

    # W168: the web list applies the same blocked-actor exclusion as the API
    # list and the shared unread badge.
    test "hides notifications from blocked actors", %{conn: conn} do
      user = user_fixture()
      harasser = user_fixture()

      {:ok, _} =
        TraysSocial.Notifications.create_notification(%{
          type: "follow",
          user_id: user.id,
          actor_id: harasser.id
        })

      {:ok, _} = TraysSocial.Accounts.block_user(user.id, harasser.id)

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/notifications")

      refute html =~ harasser.username
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
      # Editorial phrasing: "<actor> found your <title> helpful"
      assert html =~ "found your"
      assert html =~ "helpful"
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
      # Editorial phrasing: "<actor> left a note on <title>"
      assert html =~ "left a note on"
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
      # Editorial phrasing: "<actor> followed you"
      assert html =~ "followed you"
    end

    test "shows empty notifications list when none exist", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/notifications")

      assert html =~ "Notes for you"
      # The notifications stream container should be present but empty
      assert html =~ ~s|id="notifications"|
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
      assert render(view) =~ "Notes for you"
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
      assert render(view) =~ "Notes for you"
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
      assert render(view) =~ "Notes for you"
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
      assert html =~ "Notes for you"
    end
  end

  # W246: the restyled chrome: an empty block when there is nothing, a
  # rounded list and an end card when there is something.
  describe "restyle" do
    test "an empty inbox renders the Nothing yet block and keeps the stream", %{conn: conn} do
      user = user_fixture()

      {:ok, view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/notifications")

      assert has_element?(view, "#notifications-empty", "Nothing yet.")
      assert has_element?(view, "#notifications.hidden")
      refute has_element?(view, "#notifications-end")
      assert html =~ ~s|id="notifications"|
    end

    test "rows link to the actor or the post and unread rows carry the dot", %{conn: conn} do
      user = user_fixture()
      actor = user_fixture()
      post = post_fixture(user_id: user.id)

      {:ok, _} =
        Notifications.create_notification(%{
          type: "like",
          user_id: user.id,
          actor_id: actor.id,
          post_id: post.id
        })

      {:ok, _} =
        Notifications.create_notification(%{type: "follow", user_id: user.id, actor_id: actor.id})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/notifications")

      refute has_element?(view, "#notifications-empty")
      assert has_element?(view, "#notifications a[href='/posts/#{post.id}']", "helpful")
      assert has_element?(view, "#notifications a[href='/@#{actor.username}']", "followed you")
      assert has_element?(view, "#notifications span.bg-accent.rounded-full")
      assert has_element?(view, "#notifications-end")
    end

    test "a 30-character actor name wraps inside its column instead of overflowing", %{
      conn: conn
    } do
      user = user_fixture()
      long_name = String.pad_trailing("traycook", 30, "x")
      actor = user_fixture(%{username: long_name})

      {:ok, _} =
        Notifications.create_notification(%{type: "follow", user_id: user.id, actor_id: actor.id})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/notifications")

      # A username has no spaces, so only overflow-wrap:anywhere lets it break
      # inside the minmax(0,1fr) column at 390px.
      assert has_element?(
               view,
               "#notifications div.min-w-0 > p[class*='overflow-wrap:anywhere']",
               long_name
             )
    end
  end

  describe "row helpers" do
    alias TraysSocialWeb.NotificationsLive.Index

    test "a notification with no actor still has a name and a link" do
      orphan = %{type: "follow", actor: nil, post: nil}

      assert Index.actor_name(orphan) == "Someone"
      assert Index.actor_photo(orphan) == nil
      assert Index.actor_bio(orphan) == nil
      assert Index.target_path(orphan) == "/feed"
    end

    test "a follow links to the actor and a post event to the post" do
      actor = %{username: "noor", profile_photo_url: nil, bio: "Cooks"}

      assert Index.target_path(%{type: "follow", actor: actor, post: nil}) == "/@noor"
      assert Index.target_path(%{type: "like", actor: actor, post: %{id: 7}}) == "/posts/7"
      assert Index.actor_bio(%{type: "follow", actor: actor}) == "Cooks"
      assert Index.actor_bio(%{type: "like", actor: actor}) == nil
    end
  end
end
