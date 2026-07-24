defmodule TraysSocial.Repo.Migrations.CreateCollections do
  use Ecto.Migration

  def change do
    create table(:collections) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:collections, [:user_id, :name])
    create index(:collections, [:user_id])

    create table(:collection_items) do
      add :collection_id, references(:collections, on_delete: :delete_all), null: false
      add :post_id, references(:posts, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:collection_items, [:collection_id, :post_id])
    create index(:collection_items, [:collection_id])
    create index(:collection_items, [:post_id])
  end
end
