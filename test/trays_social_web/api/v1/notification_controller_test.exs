defmodule TraysSocialWeb.API.V1.NotificationControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  setup :register_and_api_authenticate_user

  describe "GET /api/v1/notifications" do
    test "returns empty list with no notifications", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/notifications")

      assert %{"data" => [], "cursor" => nil} = json_response(conn, 200)
    end

    test "returns notifications with actor info", %{conn: conn, user: user} do
      other_user = user_fixture()
      post = post_fixture(%{user_id: user.id})

      TraysSocial.Notifications.create_notification(%{
        type: "like",
        user_id: user.id,
        actor_id: other_user.id,
        post_id: post.id
      })

      conn = get(conn, ~p"/api/v1/notifications")

      assert %{"data" => [notification]} = json_response(conn, 200)
      assert notification["type"] == "like"
      assert notification["actor"]["username"] == other_user.username
      assert notification["post"]["id"] == post.id
      assert notification["read_at"] == nil
    end

    test "supports cursor pagination", %{conn: conn, user: user} do
      other_user = user_fixture()

      for _ <- 1..3 do
        TraysSocial.Notifications.create_notification(%{
          type: "follow",
          user_id: user.id,
          actor_id: other_user.id
        })
      end

      conn = get(conn, ~p"/api/v1/notifications")

      assert %{"data" => notifications, "cursor" => cursor} = json_response(conn, 200)
      assert length(notifications) == 3
      assert cursor != nil
    end

    test "does not return other user's notifications", %{conn: conn, user: _user} do
      other_user = user_fixture()
      third_user = user_fixture()

      TraysSocial.Notifications.create_notification(%{
        type: "follow",
        user_id: other_user.id,
        actor_id: third_user.id
      })

      conn = get(conn, ~p"/api/v1/notifications")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "POST /api/v1/notifications/read" do
    test "marks specific notifications as read", %{conn: conn, user: user} do
      other_user = user_fixture()

      {:ok, notif} =
        TraysSocial.Notifications.create_notification(%{
          type: "follow",
          user_id: user.id,
          actor_id: other_user.id
        })

      conn = post(conn, ~p"/api/v1/notifications/read", %{ids: [notif.id]})

      assert %{"data" => %{"marked_read" => 1}} = json_response(conn, 200)
    end

    test "does not mark other user's notifications", %{conn: conn, user: _user} do
      other_user = user_fixture()
      third_user = user_fixture()

      {:ok, notif} =
        TraysSocial.Notifications.create_notification(%{
          type: "follow",
          user_id: other_user.id,
          actor_id: third_user.id
        })

      conn = post(conn, ~p"/api/v1/notifications/read", %{ids: [notif.id]})

      assert %{"data" => %{"marked_read" => 0}} = json_response(conn, 200)
    end

    test "returns error without ids param", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/notifications/read", %{})

      assert json_response(conn, 400)
    end
  end
end
