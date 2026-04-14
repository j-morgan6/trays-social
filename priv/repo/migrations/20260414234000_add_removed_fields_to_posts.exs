defmodule TraysSocial.Repo.Migrations.AddRemovedFieldsToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :removed_at, :utc_datetime
      add :removed_by_id, references(:users, on_delete: :nilify_all)
      add :removed_reason, :string
    end
  end
end
