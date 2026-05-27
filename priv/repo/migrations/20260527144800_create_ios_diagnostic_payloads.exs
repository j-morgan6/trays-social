defmodule TraysSocial.Repo.Migrations.CreateIosDiagnosticPayloads do
  use Ecto.Migration

  def change do
    create table(:ios_diagnostic_payloads) do
      # Nullable: Apple delivers MetricKit payloads on next launch even if
      # the user has signed out since the crash occurred. We still want
      # the crash details — just without a user FK.
      add :user_id, references(:users, on_delete: :nilify_all), null: true

      # "diagnostic" (MXDiagnosticPayload — crashes, hangs, cpu/disk
      # exceptions) or "metric" (MXMetricPayload — performance metrics).
      add :payload_type, :string, null: false

      # Full Apple payload preserved as jsonb. Apple changes the inner
      # schema across iOS releases so we never validate it strictly.
      add :payload, :map, null: false

      # Extracted top-level fields for indexed querying. App and OS
      # versions help group crashes by build; device_model surfaces
      # device-specific issues.
      add :app_version, :string
      add :os_version, :string
      add :device_model, :string

      # When the server received the payload (not when the diagnostic
      # event itself happened — that lives inside the payload).
      add :received_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:ios_diagnostic_payloads, [:user_id, :received_at])
    create index(:ios_diagnostic_payloads, [:payload_type, :received_at])
  end
end
