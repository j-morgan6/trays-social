defmodule TraysSocial.Repo.Migrations.AddIsSubscriberToUsers do
  use Ecto.Migration

  # G38 monetization foundation: an account-level entitlement flag for the
  # paid tier (W160). Server-side-only — flipped by a verified purchase /
  # webhook, never by user input (mirrors :is_admin). NORTH STAR: this gates
  # the ad-free + utility experience, never recipe content.
  def change do
    alter table(:users) do
      add :is_subscriber, :boolean, null: false, default: false
    end
  end
end
