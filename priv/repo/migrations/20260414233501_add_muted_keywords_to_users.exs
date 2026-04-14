defmodule TraysSocial.Repo.Migrations.AddMutedKeywordsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :muted_keywords, {:array, :string}, default: []
    end
  end
end
