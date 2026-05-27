defmodule TraysSocial.Diagnostics do
  @moduledoc """
  Storage + read access for iOS MetricKit payloads.

  ## Why this exists

  Apple's MetricKit framework delivers crash reports and performance
  metrics from user devices as JSON payloads (`MXDiagnosticPayload` /
  `MXMetricPayload`). We accept those payloads at the API edge and
  store them here so the admin viewer (W118) and any future analytics
  can query them.

  ## Design notes

    * The inner payload shape is owned by Apple and changes across iOS
      releases. We never validate it strictly — `payload` is jsonb and
      we trust the device-side serializer.
    * Top-level metadata (`app_version`, `os_version`, `device_model`,
      `payload_type`) is extracted from the request body so the admin
      viewer can index queries without cracking the jsonb open.
    * Storage is fire-and-forget from the controller's perspective —
      no synchronous parsing, no enqueued workers. If we ever need to
      derive symbolicated stack traces or aggregate metrics, that work
      belongs in an Oban job reading from this table after the fact.
  """

  import Ecto.Query, warn: false

  alias TraysSocial.Diagnostics.IosDiagnosticPayload
  alias TraysSocial.Repo

  @doc """
  Inserts a MetricKit payload. `attrs` accepts both string and atom
  keys (see `IosDiagnosticPayload.changeset/2`); the controller passes
  the parsed JSON request body straight through plus the server-side
  `received_at` timestamp.

  Returns `{:ok, payload}` or `{:error, changeset}`.
  """
  def store_payload(attrs) do
    %IosDiagnosticPayload{}
    |> IosDiagnosticPayload.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists recent payloads in `received_at` desc order.

  ## Options

    * `:limit` — page size (default 50).
    * `:payload_type` — filter to `"diagnostic"` or `"metric"`.
    * `:user_id` — filter to one user (nil-safe).
  """
  def list_recent(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    IosDiagnosticPayload
    |> maybe_filter_payload_type(opts[:payload_type])
    |> maybe_filter_user_id(opts[:user_id])
    |> order_by([p], desc: p.received_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "Fetches a payload by id; raises on miss (admin viewer detail page)."
  def get_payload!(id), do: Repo.get!(IosDiagnosticPayload, id)

  defp maybe_filter_payload_type(query, nil), do: query

  defp maybe_filter_payload_type(query, type) when is_binary(type),
    do: where(query, [p], p.payload_type == ^type)

  defp maybe_filter_user_id(query, nil), do: query

  defp maybe_filter_user_id(query, user_id),
    do: where(query, [p], p.user_id == ^user_id)
end
