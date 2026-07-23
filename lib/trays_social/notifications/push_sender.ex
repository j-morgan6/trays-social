defmodule TraysSocial.Notifications.PushSender do
  @moduledoc """
  Sends push notifications via APNs using Pigeon.

  Pushes are sent asynchronously via Task.Supervisor to avoid
  slowing down API responses. Invalid device tokens are automatically
  cleaned up when APNs returns an error.

  Push sending is disabled by default. Enable it by setting:

      config :trays_social, :push_notifications_enabled, true

  And configuring the Pigeon APNS dispatcher in your supervision tree.
  """

  alias TraysSocial.Notifications

  require Logger

  @doc """
  Sends a push notification to all of a user's registered devices.
  Runs asynchronously — failures never affect the calling process.
  """
  def send_push(user_id, title, body, data \\ %{}) do
    if push_enabled?() do
      # D106: start_child, NOT async_nolink — async_nolink sends {ref, result}
      # and :DOWN messages to the caller, which crashes LiveView callers that
      # have no catch-all handle_info. Fire-and-forget must leave the caller's
      # mailbox untouched.
      Task.Supervisor.start_child(TraysSocial.PushTaskSupervisor, fn ->
        do_send_push(user_id, title, body, data)
      end)
    end

    :ok
  end

  defp do_send_push(user_id, title, body, data) do
    tokens = Notifications.list_device_tokens(user_id)
    dispatcher = Application.get_env(:trays_social, :apns_dispatcher, TraysSocial.APNS)

    for device_token <- tokens do
      notification =
        Pigeon.APNS.Notification.new(
          %{"title" => title, "body" => body},
          device_token.token,
          apns_topic()
        )
        |> Pigeon.APNS.Notification.put_custom(data)

      # Per-token isolation: one raising token must not abort delivery to
      # the user's remaining devices.
      try do
        case Pigeon.push(dispatcher, notification) do
          %{response: :success} ->
            :ok

          %{response: response} when response in [:bad_device_token, :unregistered] ->
            Logger.info(
              "PushSender: pruning dead device token id=#{device_token.id} (#{response})"
            )

            Notifications.delete_device_token(device_token.token)

          %{response: response} ->
            Logger.warning(
              "PushSender: APNs delivery failed for device token id=#{device_token.id}: #{inspect(response)}"
            )

          other ->
            Logger.warning(
              "PushSender: unexpected Pigeon.push result for device token id=#{device_token.id}: #{inspect(other)}"
            )
        end
      rescue
        exception ->
          Logger.error(
            "PushSender: crashed pushing to device token id=#{device_token.id} for user_id=#{user_id}: " <>
              Exception.format(:error, exception, __STACKTRACE__)
          )

          :ok
      end
    end
  end

  defp push_enabled? do
    Application.get_env(:trays_social, :push_notifications_enabled, false)
  end

  defp apns_topic do
    Application.get_env(:trays_social, :apns_topic, "com.trays.social")
  end
end
