defmodule TraysSocial.Repo.Migrations.MakeCaptionNullableOnPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      modify :caption, :string, null: true, from: {:string, null: false}
    end
  end
end
