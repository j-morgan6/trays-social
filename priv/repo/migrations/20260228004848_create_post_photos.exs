defmodule TraysSocial.Repo.Migrations.CreatePostPhotos do
  use Ecto.Migration

  def change do
    create table(:post_photos) do
      add :url, :string, null: false
      add :position, :integer, null: false
      add :post_id, references(:posts, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:post_photos, [:post_id])
  end
end
