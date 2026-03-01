defmodule TraysSocial.Repo.Migrations.CreatePostComments do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :comment_count, :integer, default: 0, null: false
    end

    create table(:post_comments) do
      add :body, :text, null: false
      add :deleted_at, :utc_datetime
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:post_comments, [:post_id])
    create index(:post_comments, [:user_id])
  end
end
