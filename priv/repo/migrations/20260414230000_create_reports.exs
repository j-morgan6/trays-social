defmodule TraysSocial.Repo.Migrations.CreateReports do
  use Ecto.Migration

  def change do
    create table(:reports) do
      add :reporter_id, references(:users, on_delete: :delete_all), null: false
      add :target_type, :string, null: false
      add :target_id, :integer, null: false
      add :reason, :string, null: false
      add :details, :text
      add :status, :string, null: false, default: "open"
      add :resolved_at, :utc_datetime
      add :resolved_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:reports, [:reporter_id])
    create index(:reports, [:target_type, :target_id])
    create index(:reports, [:status])
    create unique_index(:reports, [:reporter_id, :target_type, :target_id],
      name: :reports_reporter_target_unique,
      where: "status = 'open'"
    )
  end
end
