defmodule TraysSocial.Notifications.PushSenderTest do
  # async: false — the message-leak test toggles the
  # :push_notifications_enabled app env, which is global.
  use TraysSocial.DataCase, async: false

  import ExUnit.CaptureLog

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

    # D106 regression: async_nolink leaked {ref, result} and :DOWN messages
    # into the caller's mailbox, crashing LiveView callers with no catch-all
    # handle_info. Fire-and-forget must leave the caller's mailbox untouched.
    test "with push enabled, sends no messages to the calling process" do
      user = user_fixture()
      {:ok, _} = Notifications.register_device(user.id, "test_token_leak")

      Application.put_env(:trays_social, :push_notifications_enabled, true)
      on_exit(fn -> Application.delete_env(:trays_social, :push_notifications_enabled) end)

      capture_log(fn ->
        assert PushSender.send_push(user.id, "Title", "Body") == :ok
        # async_nolink would deliver {ref, result} and a :DOWN here.
        refute_receive _, 300
      end)
    end
  end
end
