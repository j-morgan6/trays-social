defmodule TraysSocialWeb.Webhooks.AppStoreController do
  use TraysSocialWeb, :controller

  alias TraysSocial.Monetization.AppStore
  alias TraysSocial.Monetization.Subscriptions

  require Logger

  # W174: App Store Server Notifications V2. Apple posts here, so the route is
  # intentionally unauthenticated — which makes verifying signedPayload BEFORE
  # any database access the whole security boundary. The DB call exists only
  # inside the {:ok, notification} branch, so there is no path from params to
  # a write that skips verification.
  #
  # Unlike the Resend webhook this does NOT need conn.assigns[:raw_body]:
  # Apple's signature is inside the JWS, so the parsed params are sufficient.
  #
  # Status contract — Apple retries for three days on any non-2xx:
  #   401 -> signature did not verify (the ONLY rejection)
  #   400 -> structurally absent signedPayload
  #   200 -> everything Apple-signed, including unknown types, a bundle or
  #          environment that is not ours, and transactions we have no user for
  # A signature failure is the ONLY thing that earns a rejection. Every other
  # error is a semantic one on a payload Apple genuinely signed (a bundle or
  # product that is not ours, an envelope shape we do not model, a
  # notification type we take no action on) — those get acked, because a
  # non-2xx makes Apple retry for three days.
  @signature_failures [
    :malformed_jws,
    :invalid_certificate_chain,
    :untrusted_certificate_chain,
    :invalid_signature
  ]

  def receive(conn, %{"signedPayload" => signed_payload}) when is_binary(signed_payload) do
    case AppStore.verify_notification(signed_payload) do
      {:ok, notification} ->
        handle(conn, notification)

      {:error, reason} when reason in @signature_failures ->
        Logger.warning("app store webhook: rejected (#{reason})")
        send_resp(conn, 401, "")

      {:error, reason} ->
        Logger.warning("app store webhook: acking unactionable notification (#{reason})")
        send_resp(conn, 200, "")
    end
  end

  def receive(conn, _params) do
    Logger.warning("app store webhook: missing signedPayload")
    send_resp(conn, 400, "")
  end

  defp handle(conn, notification) do
    # The action was resolved during verification, from the signature-verified
    # outer claims — recomputing it here would risk the two disagreeing.
    #
    # Deliberately no dedupe table: set_subscriber/2 is idempotent, so Apple's
    # retries are harmless. The UUID is logged so duplicates stay visible.
    Logger.info(
      "app store webhook: #{notification.type} -> #{notification.action} (uuid=#{notification.uuid})"
    )

    apply_action(notification.action, notification)
    send_resp(conn, 200, "")
  end

  defp apply_action(:ignore, _notification), do: :ok

  defp apply_action(action, notification) do
    case Subscriptions.apply_notification(notification.transaction, action) do
      {:ok, _user} ->
        :ok

      # No account holds this transaction: a purchase whose /verify never
      # landed, or a deleted account. Expected — ack and move on.
      {:error, :user_not_found} ->
        Logger.warning("app store webhook: no user holds this transaction")
        :ok

      {:error, reason} ->
        Logger.warning("app store webhook: entitlement update failed (#{inspect(reason)})")
        :ok
    end
  end
end
