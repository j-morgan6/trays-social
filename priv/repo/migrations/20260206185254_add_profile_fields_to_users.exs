defmodule TraysSocial.Repo.Migrations.AddProfileFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :username, :string
      add :bio, :text
      add :profile_photo_url, :string
    end

    create unique_index(:users, [:username])
  end
end
