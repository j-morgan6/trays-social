defmodule TraysSocial.Repo.Migrations.FixFeedbackSubmissionsUserFk do
  use Ecto.Migration

  # D103: the FK was declared on_delete: :nilify_all on a NOT NULL column,
  # so deleting a user who ever submitted feedback raised not_null_violation
  # and rolled back the whole delete_account transaction. Feedback belongs
  # to the account; it is deleted with it.
  def up do
    drop constraint(:feedback_submissions, "feedback_submissions_user_id_fkey")

    alter table(:feedback_submissions) do
      modify :user_id, references(:users, on_delete: :delete_all), null: false
    end
  end

  def down do
    drop constraint(:feedback_submissions, "feedback_submissions_user_id_fkey")

    alter table(:feedback_submissions) do
      modify :user_id, references(:users, on_delete: :nilify_all), null: false
    end
  end
end
