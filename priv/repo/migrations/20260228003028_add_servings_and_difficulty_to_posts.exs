defmodule TraysSocial.Repo.Migrations.AddServingsAndDifficultyToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :servings, :integer
      add :difficulty, :string
    end
  end
end
