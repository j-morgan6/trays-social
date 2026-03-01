defmodule TraysSocial.Repo.Migrations.CreatePostLikes do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :like_count, :integer, default: 0, null: false
    end

    create table(:post_likes) do
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:post_likes, [:post_id])
    create index(:post_likes, [:user_id])
    create unique_index(:post_likes, [:post_id, :user_id])
  end
end
