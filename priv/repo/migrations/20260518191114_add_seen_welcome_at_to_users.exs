defmodule TraysSocial.Repo.Migrations.AddSeenWelcomeAtToUsers do
  use Ecto.Migration

  def change do
    # Additive nullable column. Existing users get nil and will be
    # one-time-redirected through /welcome on their next sign-in; the
    # welcome screen's "Got it" action stamps this so they never see it
    # again.
    alter table(:users) do
      add :seen_welcome_at, :utc_datetime
    end
  end
end
