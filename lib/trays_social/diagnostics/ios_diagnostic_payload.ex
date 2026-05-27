defmodule TraysSocial.Diagnostics.IosDiagnosticPayload do
  @moduledoc """
  One MetricKit payload from a user device.

  Apple delivers two payload kinds:
    * `"diagnostic"` — `MXDiagnosticPayload` (crashes, hangs, CPU/disk
      exceptions). Posted on next launch after the relevant event.
    * `"metric"`     — `MXMetricPayload` (performance metrics, ~once
      per day).

  We persist the raw `payload` as jsonb and never validate its inner
  shape — Apple changes the structure across iOS releases. A handful of
  top-level fields are extracted from the request body and stored as
  columns so the admin viewer can filter by app/OS/device without
  cracking the jsonb open.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @payload_types ~w(diagnostic metric)

  schema "ios_diagnostic_payloads" do
    field :payload_type, :string
    field :payload, :map
    field :app_version, :string
    field :os_version, :string
    field :device_model, :string
    field :received_at, :utc_datetime

    belongs_to :user, TraysSocial.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(payload, attrs) do
    payload
    |> cast(attrs, [
      :user_id,
      :payload_type,
      :payload,
      :app_version,
      :os_version,
      :device_model,
      :received_at
    ])
    |> validate_required([:payload_type, :payload, :received_at])
    |> validate_inclusion(:payload_type, @payload_types)
    |> validate_length(:app_version, max: 64)
    |> validate_length(:os_version, max: 64)
    |> validate_length(:device_model, max: 128)
    |> foreign_key_constraint(:user_id)
  end

  @doc "Allowed values for the `payload_type` column."
  def payload_types, do: @payload_types
end
