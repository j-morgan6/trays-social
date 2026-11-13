defmodule TraysSocial.Repo.Migrations.AddContextToFeedbackSubmissions do
  use Ecto.Migration

  # W260: bug-report context for feedback submissions.
  #
  # kind and platform are NOT NULL with constant defaults, so PostgreSQL
  # fills every existing row in place (no table rewrite on PG11+): rows
  # stored before this migration read as kind "feedback" and platform
  # "ios", which is the only client that existed. user_id is untouched;
  # D103 (20260702200500) already made it NOT NULL with on_delete
  # delete_all.
  def change do
    alter table(:feedback_submissions) do
      add :kind, :string, null: false, default: "feedback"
      add :platform, :string, size: 16, null: false, default: "ios"
      add :app_build, :string, size: 64
      add :screen, :string, size: 120
      add :user_agent, :string, size: 512
    end
  end
end
