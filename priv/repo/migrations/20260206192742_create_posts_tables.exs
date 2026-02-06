defmodule TraysSocial.Repo.Migrations.CreatePostsTables do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :user_id, references(:users, on_delete: :nothing), null: false
      add :photo_url, :string, null: false
      add :caption, :string, size: 500, null: false
      add :cooking_time_minutes, :integer, null: false
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:posts, [:user_id])
    create index(:posts, [:inserted_at])
    create index(:posts, [:deleted_at])

    create table(:ingredients) do
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :quantity, :string
      add :unit, :string
      add :order, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:ingredients, [:post_id])
    create index(:ingredients, [:name])

    create table(:tools) do
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :order, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:tools, [:post_id])

    create table(:cooking_steps) do
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :description, :string, size: 300, null: false
      add :order, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:cooking_steps, [:post_id])

    create table(:post_tags) do
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :tag, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:post_tags, [:post_id])
    create index(:post_tags, [:tag])
  end
end
