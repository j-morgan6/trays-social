defmodule TraysSocial.Repo.Migrations.AddTypeAndRemoveDifficultyFromPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :type, :string, null: false, default: "recipe"
      remove :difficulty, :string
    end
  end
end
