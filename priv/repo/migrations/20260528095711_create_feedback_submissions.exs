defmodule TraysSocial.Repo.Migrations.CreateFeedbackSubmissions do
  use Ecto.Migration

  def change do
    create table(:feedback_submissions) do
      add :user_id, references(:users, on_delete: :nilify_all), null: false
      add :subject, :string, size: 200
      add :body, :text, null: false
      add :app_version, :string, size: 64
      add :os_version, :string, size: 64
      add :device_model, :string, size: 128

      # new | triaged | resolved — kept as a string + Ecto inclusion
      # rather than a Postgres enum so we can add states without a
      # migration (mirrors the ios_diagnostic_payloads pattern from
      # W117).
      add :status, :string, null: false, default: "new"

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:feedback_submissions, [:status, :inserted_at])
    create index(:feedback_submissions, [:user_id, :inserted_at])
  end
end
