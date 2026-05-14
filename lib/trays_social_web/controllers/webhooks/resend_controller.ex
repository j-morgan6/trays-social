defmodule TraysSocialWeb.Webhooks.ResendController do
  @moduledoc """
  Receives Resend webhook deliveries (Svix-format signed POSTs) and
  persists them to the `email_events` table.

  Authentication is via Svix signature verification using the per-endpoint
  signing secret. There is no CSRF (third-party origin), and no rate limit
  (Resend's retries on 5xx need to be captured).

  Logging keeps PII off Fly stdout: only `svix-id` and `event_type` are
  logged at info level. The recipient lives in the persisted row, gated
  behind the admin view at `/admin/email-events`.
  """

  use TraysSocialWeb, :controller

  require Logger

  alias TraysSocial.Email

  # 5-minute window — events older than this are rejected to limit replay
  # attacks. Matches Svix's default.
  @max_timestamp_skew_seconds 5 * 60

  @doc """
  Accepts a Resend webhook POST. Validates the Svix signature, parses the
  event, and inserts or no-ops by `event_id`.

  Returns 200 with empty body on success (including idempotent retry),
  401 on signature failure, 422 on malformed payload.
  """
  def receive(conn, _params) do
    with {:ok, raw_body} <- read_raw_body(conn),
         :ok <- verify_signature(conn, raw_body),
         {:ok, payload} <- Jason.decode(raw_body),
         {:ok, attrs} <- extract_event_attrs(payload),
         {:ok, _event} <- Email.upsert_event(attrs) do
      Logger.info(
        "resend webhook accepted: event_type=#{attrs.event_type} svix_id=#{header_one(conn, "svix-id")}"
      )

      send_resp(conn, 200, "")
    else
      {:error, :missing_signing_secret} ->
        # Logger.error already fired inside verify_signature/2; 401 to the
        # caller so they retry once the operator sets the secret.
        send_resp(conn, 401, "")

      {:error, :missing_signature_headers} ->
        Logger.warning("resend webhook rejected: missing signature headers")
        send_resp(conn, 401, "")

      {:error, :invalid_signature} ->
        Logger.warning(
          "resend webhook rejected: signature verification failed svix_id=#{header_one(conn, "svix-id")}"
        )

        send_resp(conn, 401, "")

      {:error, :timestamp_skew} ->
        Logger.warning(
          "resend webhook rejected: timestamp outside ±#{@max_timestamp_skew_seconds}s window"
        )

        send_resp(conn, 401, "")

      {:error, :no_raw_body} ->
        # Hit when the endpoint pipeline parsed JSON before we could read
        # the raw body. Indicates a router-config mistake (the :webhook
        # pipeline must skip the JSON parser); fail loudly so it doesn't
        # silently accept unsigned events.
        Logger.error("resend webhook: raw body unavailable — router pipeline is parsing JSON before the controller")
        send_resp(conn, 500, "")

      {:error, :invalid_payload} ->
        Logger.warning("resend webhook rejected: payload missing required fields")
        send_resp(conn, 422, "")

      {:error, %Jason.DecodeError{}} ->
        Logger.warning("resend webhook rejected: body is not valid JSON")
        send_resp(conn, 422, "")

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("resend webhook event upsert failed: #{inspect(changeset.errors)}")
        send_resp(conn, 500, "")
    end
  end

  ## ---------- private ----------

  # Returns the raw, unparsed body of the request. The :webhook router
  # pipeline must use Plug.Parsers with body_reader: BodyReader so the raw
  # body is preserved in conn.assigns[:raw_body] (see router config). We
  # check the assign first to avoid double-consuming the body.
  defp read_raw_body(%Plug.Conn{assigns: %{raw_body: raw}} = _conn) when is_binary(raw),
    do: {:ok, raw}

  defp read_raw_body(_conn), do: {:error, :no_raw_body}

  defp verify_signature(conn, raw_body) do
    case signing_secret() do
      nil ->
        # No secret configured. Reject every event to prevent unsigned
        # ingress in any environment. Tests + dev set their own secret via
        # Application.put_env before exercising the endpoint.
        Logger.error(
          "resend webhook: RESEND_WEBHOOK_SIGNING_SECRET is not set on this environment — rejecting all events. Configure it via `fly secrets set` and restart."
        )

        {:error, :missing_signing_secret}

      secret ->
        do_verify_signature(conn, raw_body, secret)
    end
  end

  defp do_verify_signature(conn, raw_body, secret) do
    with svix_id when is_binary(svix_id) <- header_one(conn, "svix-id"),
         svix_timestamp when is_binary(svix_timestamp) <- header_one(conn, "svix-timestamp"),
         svix_signature when is_binary(svix_signature) <- header_one(conn, "svix-signature"),
         :ok <- check_timestamp_skew(svix_timestamp) do
      payload_to_sign = "#{svix_id}.#{svix_timestamp}.#{raw_body}"
      expected = compute_signature(secret, payload_to_sign)

      # svix-signature header may carry multiple signatures separated by
      # spaces, each prefixed with a version label (e.g. "v1,<base64>").
      # Constant-time compare against each.
      signatures =
        svix_signature
        |> String.split(" ", trim: true)
        |> Enum.map(&strip_version_prefix/1)

      if Enum.any?(signatures, fn sig -> constant_time_equal?(sig, expected) end) do
        :ok
      else
        {:error, :invalid_signature}
      end
    else
      _ -> {:error, :missing_signature_headers}
    end
  end

  defp check_timestamp_skew(svix_timestamp) do
    with {ts, ""} <- Integer.parse(svix_timestamp),
         now <- System.system_time(:second),
         true <- abs(now - ts) <= @max_timestamp_skew_seconds do
      :ok
    else
      _ -> {:error, :timestamp_skew}
    end
  end

  # Svix signature spec: base64(HMAC-SHA256(secret, "<svix-id>.<svix-ts>.<body>"))
  # The secret itself is base64-encoded after the "whsec_" prefix.
  defp compute_signature("whsec_" <> b64_secret, payload) do
    secret = Base.decode64!(b64_secret)
    :crypto.mac(:hmac, :sha256, secret, payload) |> Base.encode64()
  end

  defp compute_signature(secret, payload) do
    # Allow a raw (non-whsec_-prefixed) secret too — useful for tests and
    # for ops that store the secret without the prefix.
    :crypto.mac(:hmac, :sha256, secret, payload) |> Base.encode64()
  end

  defp strip_version_prefix(sig) do
    case String.split(sig, ",", parts: 2) do
      [_version, body] -> body
      [body] -> body
    end
  end

  defp constant_time_equal?(a, b) when is_binary(a) and is_binary(b) do
    :crypto.hash_equals(a, b)
  end

  defp header_one(conn, name) do
    case Plug.Conn.get_req_header(conn, name) do
      [value | _] -> value
      [] -> nil
    end
  end

  defp extract_event_attrs(%{"type" => event_type, "data" => data} = payload)
       when is_binary(event_type) and is_map(data) do
    with email_id when is_binary(email_id) <- data["email_id"] || data["id"],
         recipient when is_binary(recipient) <- extract_recipient(data),
         event_id when is_binary(event_id) <- payload["id"] || data["id"] do
      {:ok,
       %{
         event_id: event_id,
         email_id: email_id,
         event_type: event_type,
         recipient: recipient,
         payload: payload
       }}
    else
      _ -> {:error, :invalid_payload}
    end
  end

  defp extract_event_attrs(_), do: {:error, :invalid_payload}

  defp extract_recipient(%{"to" => [first | _]}) when is_binary(first), do: first
  defp extract_recipient(%{"to" => to}) when is_binary(to), do: to
  defp extract_recipient(_), do: nil

  defp signing_secret do
    Application.get_env(:trays_social, :resend_webhook_signing_secret)
  end
end
