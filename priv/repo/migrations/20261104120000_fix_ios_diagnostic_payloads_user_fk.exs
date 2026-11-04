defmodule TraysSocial.Repo.Migrations.FixIosDiagnosticPayloadsUserFk do
  use Ecto.Migration

  # D120: the FK was on_delete: :nilify_all, so deleting an account kept the
  # user's MetricKit reports with the user link removed. The Privacy Policy
  # promises account deletion removes the account's data, so the reports are
  # deleted with it. Signed-out payloads (user_id null) are unaffected.
  def after_begin do
    repo().query!("SET LOCAL lock_timeout TO '5s'")
  end

  def up do
    drop constraint(:ios_diagnostic_payloads, "ios_diagnostic_payloads_user_id_fkey")

    alter table(:ios_diagnostic_payloads) do
      modify :user_id, references(:users, on_delete: :delete_all), null: true
    end
  end

  def down do
    drop constraint(:ios_diagnostic_payloads, "ios_diagnostic_payloads_user_id_fkey")

    alter table(:ios_diagnostic_payloads) do
      modify :user_id, references(:users, on_delete: :nilify_all), null: true
    end
  end
end
