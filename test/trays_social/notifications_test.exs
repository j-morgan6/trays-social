defmodule TraysSocial.NotificationsTest do
  use TraysSocial.DataCase, async: true

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Notifications
  alias TraysSocial.Notifications.Notification

  setup do
    user = user_fixture()
    actor = user_fixture()
    post = post_fixture(user_id: user.id)

    %{user: user, actor: actor, post: post}
  end

  describe "create_notification/1" do
    test "creates a like notification", %{user: user, actor: actor, post: post} do
      attrs = %{type: "like", user_id: user.id, actor_id: actor.id, post_id: post.id}

      assert {:ok, %Notification{} = notification} = Notifications.create_notification(attrs)
      assert notification.type == "like"
      assert notification.user_id == user.id
      assert notification.actor_id == actor.id
      assert notification.post_id == post.id
      assert notification.read_at == nil
    end

    test "creates a comment notification", %{user: user, actor: actor, post: post} do
      attrs = %{type: "comment", user_id: user.id, actor_id: actor.id, post_id: post.id}

      assert {:ok, %Notification{}} = Notifications.create_notification(attrs)
    end

    test "creates a follow notification without a post", %{user: user, actor: actor} do
      attrs = %{type: "follow", user_id: user.id, actor_id: actor.id}

      assert {:ok, %Notification{} = notification} = Notifications.create_notification(attrs)
      assert notification.type == "follow"
      assert notification.post_id == nil
    end

    test "preloads actor and post associations", %{user: user, actor: actor, post: post} do
      attrs = %{type: "like", user_id: user.id, actor_id: actor.id, post_id: post.id}

      assert {:ok, %Notification{} = notification} = Notifications.create_notification(attrs)
      assert notification.actor.id == actor.id
      assert notification.post.id == post.id
    end

    test "skips self-notifications", %{user: user, post: post} do
      attrs = %{type: "like", user_id: user.id, actor_id: user.id, post_id: post.id}

      assert {:ok, :skipped} = Notifications.create_notification(attrs)
    end

    test "skips when user_id is nil", %{actor: actor} do
      attrs = %{type: "like", user_id: nil, actor_id: actor.id}

      assert {:ok, :skipped} = Notifications.create_notification(attrs)
    end

    test "skips when actor_id is nil", %{user: user} do
      attrs = %{type: "like", user_id: user.id, actor_id: nil}

      assert {:ok, :skipped} = Notifications.create_notification(attrs)
    end

    test "returns error for invalid notification type", %{user: user, actor: actor} do
      attrs = %{type: "invalid_type", user_id: user.id, actor_id: actor.id}

      assert {:error, changeset} = Notifications.create_notification(attrs)
      assert %{type: _} = errors_on(changeset)
    end

    test "returns error when type is missing", %{user: user, actor: actor} do
      attrs = %{user_id: user.id, actor_id: actor.id}

      assert {:error, changeset} = Notifications.create_notification(attrs)
      assert %{type: ["can't be blank"]} = errors_on(changeset)
    end

    test "broadcasts notification via PubSub", %{user: user, actor: actor, post: post} do
      Phoenix.PubSub.subscribe(TraysSocial.PubSub, "notifications:#{user.id}")

      attrs = %{type: "like", user_id: user.id, actor_id: actor.id, post_id: post.id}
      {:ok, notification} = Notifications.create_notification(attrs)

      assert_receive {:new_notification, ^notification}
    end
  end

  describe "list_notifications/1" do
    test "returns all notifications for a user", %{user: user, actor: actor, post: post} do
      attrs1 = %{type: "like", user_id: user.id, actor_id: actor.id, post_id: post.id}
      attrs2 = %{type: "comment", user_id: user.id, actor_id: actor.id, post_id: post.id}
      attrs3 = %{type: "follow", user_id: user.id, actor_id: actor.id}

      {:ok, _n1} = Notifications.create_notification(attrs1)
      {:ok, _n2} = Notifications.create_notification(attrs2)
      {:ok, _n3} = Notifications.create_notification(attrs3)

      notifications = Notifications.list_notifications(user.id)

      assert length(notifications) == 3
      types = Enum.map(notifications, & &1.type) |> Enum.sort()
      assert types == ["comment", "follow", "like"]

      # Verify ordering: inserted_at is descending
      timestamps = Enum.map(notifications, & &1.inserted_at)
      assert timestamps == Enum.sort(timestamps, {:desc, DateTime})
    end

    test "does not return other users' notifications", %{user: user, actor: actor, post: post} do
      other_user = user_fixture()

      {:ok, _} =
        Notifications.create_notification(%{
          type: "like",
          user_id: other_user.id,
          actor_id: actor.id,
          post_id: post.id
        })

      {:ok, _} =
        Notifications.create_notification(%{
          type: "follow",
          user_id: user.id,
          actor_id: actor.id
        })

      assert [notification] = Notifications.list_notifications(user.id)
      assert notification.user_id == user.id
    end

    test "returns empty list when user has no notifications", %{user: _user} do
      new_user = user_fixture()
      assert [] = Notifications.list_notifications(new_user.id)
    end

    test "preloads actor and post associations", %{user: user, actor: actor, post: post} do
      {:ok, _} =
        Notifications.create_notification(%{
          type: "like",
          user_id: user.id,
          actor_id: actor.id,
          post_id: post.id
        })

      [notification] = Notifications.list_notifications(user.id)

      assert %TraysSocial.Accounts.User{} = notification.actor
      assert %TraysSocial.Posts.Post{} = notification.post
    end
  end

  describe "mark_all_read/1" do
    test "marks all unread notifications as read", %{user: user, actor: actor} do
      {:ok, _} =
        Notifications.create_notification(%{
          type: "follow",
          user_id: user.id,
          actor_id: actor.id
        })

      {:ok, _} =
        Notifications.create_notification(%{
          type: "follow",
          user_id: user.id,
          actor_id: actor.id
        })

      assert :ok = Notifications.mark_all_read(user.id)

      notifications = Notifications.list_notifications(user.id)
      assert Enum.all?(notifications, fn n -> n.read_at != nil end)
    end

    test "returns :ok even when no unread notifications exist", %{user: user} do
      assert :ok = Notifications.mark_all_read(user.id)
    end

    test "does not affect already read notifications", %{user: user, actor: actor} do
      {:ok, _} =
        Notifications.create_notification(%{
          type: "follow",
          user_id: user.id,
          actor_id: actor.id
        })

      :ok = Notifications.mark_all_read(user.id)
      [n1] = Notifications.list_notifications(user.id)
      first_read_at = n1.read_at

      # Mark again -- should not change timestamp
      :ok = Notifications.mark_all_read(user.id)
      [n2] = Notifications.list_notifications(user.id)
      assert n2.read_at == first_read_at
    end

    test "does not affect other users' notifications", %{user: user, actor: actor} do
      other_user = user_fixture()

      {:ok, _} =
        Notifications.create_notification(%{
          type: "follow",
          user_id: other_user.id,
          actor_id: actor.id
        })

      {:ok, _} =
        Notifications.create_notification(%{
          type: "follow",
          user_id: user.id,
          actor_id: actor.id
        })

      :ok = Notifications.mark_all_read(user.id)

      [other_notification] = Notifications.list_notifications(other_user.id)
      assert other_notification.read_at == nil
    end

    test "broadcasts read event via PubSub when there are unread notifications", %{
      user: user,
      actor: actor
    } do
      {:ok, _} =
        Notifications.create_notification(%{
          type: "follow",
          user_id: user.id,
          actor_id: actor.id
        })

      Phoenix.PubSub.subscribe(TraysSocial.PubSub, "notifications:#{user.id}")

      Notifications.mark_all_read(user.id)

      assert_receive {:notifications_read, user_id}
      assert user_id == user.id
    end
  end

  describe "unread_count/1" do
    test "returns 0 when user has no notifications", %{user: _user} do
      new_user = user_fixture()
      assert 0 == Notifications.unread_count(new_user.id)
    end

    test "counts unread notifications", %{user: user, actor: actor} do
      {:ok, _} =
        Notifications.create_notification(%{
          type: "follow",
          user_id: user.id,
          actor_id: actor.id
        })

      {:ok, _} =
        Notifications.create_notification(%{
          type: "follow",
          user_id: user.id,
          actor_id: actor.id
        })

      assert 2 == Notifications.unread_count(user.id)
    end

    test "does not count read notifications", %{user: user, actor: actor} do
      {:ok, _} =
        Notifications.create_notification(%{
          type: "follow",
          user_id: user.id,
          actor_id: actor.id
        })

      {:ok, _} =
        Notifications.create_notification(%{
          type: "follow",
          user_id: user.id,
          actor_id: actor.id
        })

      Notifications.mark_all_read(user.id)

      assert 0 == Notifications.unread_count(user.id)
    end

    test "only counts notifications for the specified user", %{user: user, actor: actor} do
      other_user = user_fixture()

      {:ok, _} =
        Notifications.create_notification(%{
          type: "follow",
          user_id: user.id,
          actor_id: actor.id
        })

      {:ok, _} =
        Notifications.create_notification(%{
          type: "follow",
          user_id: other_user.id,
          actor_id: actor.id
        })

      assert 1 == Notifications.unread_count(user.id)
    end
  end
end
