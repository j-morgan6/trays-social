defmodule TraysSocial.Repo.Migrations.AddSuspendedUntilToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :suspended_until, :utc_datetime
    end
  end
end
