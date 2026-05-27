defmodule TraysSocialWeb.API.V1.IosDiagnosticController do
  @moduledoc """
  Accepts MetricKit payloads from iOS clients.

  ## Endpoint

      POST /api/v1/ios_diagnostics

  ## Body

      {
        "payload_type": "diagnostic" | "metric",
        "payload":      { ...raw MX*Payload JSON from MetricKit... },
        "app_version":  "1.0.0",
        "os_version":   "17.5",
        "device_model": "iPhone15,3"
      }

  ## Auth + rate limiting

    * Authentication required (pipe_through `:api_auth`). Apple delivers
      payloads on next launch, by which time the user may have signed
      out — clients that surface that case should silently drop the
      payload rather than retrying without auth. (V1 trade-off: keeps
      the user_id correlation and matches the existing API surface.)
    * Rate limited to 1 request per user per minute via the dedicated
      `api_rate_limit_diagnostics` pipeline in the router. Apple
      itself only delivers a payload at most once per day per device,
      so this is generous but cheap insurance against client retry
      storms.

  ## Pitfalls (per W117 spec)

    * The inner Apple payload is **not** validated — Apple's schema
      changes across iOS releases. We accept any well-formed map.
    * Logging never includes the raw payload at info level — it can
      hold file paths that count as PII. Only top-level metadata is
      logged.
  """

  use TraysSocialWeb, :controller

  require Logger

  alias TraysSocial.Diagnostics

  action_fallback TraysSocialWeb.API.V1.FallbackController

  def create(conn, %{"payload_type" => payload_type, "payload" => payload} = params)
      when is_map(payload) do
    user = conn.assigns[:current_user]

    attrs = %{
      user_id: user && user.id,
      payload_type: payload_type,
      payload: payload,
      app_version: params["app_version"],
      os_version: params["os_version"],
      device_model: params["device_model"],
      received_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    case Diagnostics.store_payload(attrs) do
      {:ok, record} ->
        Logger.info(
          "ios_diagnostic stored: id=#{record.id} type=#{payload_type} " <>
            "user_id=#{record.user_id} app=#{record.app_version} os=#{record.os_version}"
        )

        conn
        |> put_status(:created)
        |> json(%{data: %{id: record.id, received_at: record.received_at}})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset_errors(changeset)})
    end
  end

  # Missing or malformed top-level fields. We never look inside the
  # payload to validate.
  def create(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      errors: [
        %{field: "payload_type", message: "is required"},
        %{field: "payload", message: "is required and must be an object"}
      ]
    })
  end

  defp changeset_errors(changeset) do
    Enum.flat_map(changeset.errors, fn {field, {msg, _opts}} ->
      [%{field: to_string(field), message: msg}]
    end)
  end
end
