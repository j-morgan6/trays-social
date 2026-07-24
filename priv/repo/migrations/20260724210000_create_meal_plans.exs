defmodule TraysSocial.Repo.Migrations.CreateMealPlans do
  use Ecto.Migration

  def change do
    create table(:meal_plan_entries) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :date, :date, null: false
      add :post_id, references(:posts, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:meal_plan_entries, [:user_id, :date, :post_id])
    create index(:meal_plan_entries, [:user_id])
    create index(:meal_plan_entries, [:post_id])

    create table(:grocery_checks) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :week_start, :date, null: false
      add :item_key, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:grocery_checks, [:user_id, :week_start, :item_key])
    create index(:grocery_checks, [:user_id, :week_start])
  end
end
