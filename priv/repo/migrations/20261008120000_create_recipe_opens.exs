defmodule TraysSocial.Repo.Migrations.CreateRecipeOpens do
  use Ecto.Migration

  def change do
    create table(:recipe_opens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :last_opened_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:recipe_opens, [:user_id, :post_id])
    create index(:recipe_opens, [:post_id])
  end
end
