defmodule TraysSocial.Repo.Migrations.MakeCookingTimeNullableOnPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      modify :cooking_time_minutes, :integer, null: true, from: {:integer, null: false}
    end
  end
end
