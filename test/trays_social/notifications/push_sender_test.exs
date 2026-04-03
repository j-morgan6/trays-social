defmodule TraysSocial.Notifications.PushSenderTest do
  use TraysSocial.DataCase, async: true

  alias TraysSocial.Notifications
  alias TraysSocial.Notifications.PushSender

  import TraysSocial.AccountsFixtures

  describe "send_push/4" do
    test "returns :ok when push is disabled (default)" do
      assert PushSender.send_push(1, "Title", "Body") == :ok
    end

    test "returns :ok when user has no device tokens" do
      user = user_fixture()
      assert PushSender.send_push(user.id, "Title", "Body") == :ok
    end

    test "does not crash when push is disabled and user has tokens" do
      user = user_fixture()
      {:ok, _} = Notifications.register_device(user.id, "test_token_push")
      assert PushSender.send_push(user.id, "Title", "Body") == :ok
    end
  end
end
