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

  @doc """
  Sends a push notification to all of a user's registered devices.
  Runs asynchronously — failures never affect the calling process.
  """
  def send_push(user_id, title, body, data \\ %{}) do
    if push_enabled?() do
      Task.Supervisor.async_nolink(TraysSocial.PushTaskSupervisor, fn ->
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

      case Pigeon.push(dispatcher, notification) do
        %{response: :success} ->
          :ok

        %{response: response} when response in [:bad_device_token, :unregistered] ->
          Notifications.delete_device_token(device_token.token)

        _ ->
          :ok
      end
    end
  rescue
    _ -> :ok
  end

  defp push_enabled? do
    Application.get_env(:trays_social, :push_notifications_enabled, false)
  end

  defp apns_topic do
    Application.get_env(:trays_social, :apns_topic, "com.trays.social")
  end
end
