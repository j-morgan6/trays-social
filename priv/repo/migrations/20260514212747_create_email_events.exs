defmodule TraysSocial.Repo.Migrations.CreateEmailEvents do
  use Ecto.Migration

  def change do
    create table(:email_events) do
      # Resend's per-event UUID. Indexed unique so retries of the same
      # webhook event are idempotent (Repo.insert with on_conflict: :nothing).
      add :event_id, :string, null: false

      # Resend's per-email UUID, common across the chain of events for one
      # send (sent -> delivered -> opened, etc.). Indexed for "show all
      # events for this send" admin queries.
      add :email_id, :string, null: false

      # email.sent / email.delivered / email.bounced / email.complained /
      # email.delivery_delayed / email.opened / email.clicked
      add :event_type, :string, null: false

      # Recipient email — kept here for admin filtering even though it's
      # also inside the payload. Treat as PII; never log at info level.
      add :recipient, :string, null: false

      # Full Resend webhook payload preserved as jsonb for forensic detail
      # without forcing us to model every event variant up-front.
      add :payload, :map, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:email_events, [:event_id])
    create index(:email_events, [:email_id])
    create index(:email_events, [:recipient])
    create index(:email_events, [:inserted_at])
  end
end
