defmodule TraysSocial.Repo.Migrations.AddAppleOriginalTransactionIdToUsers do
  use Ecto.Migration

  # W174: maps a verified StoreKit 2 subscription to a Trays account so App
  # Store Server Notifications (which carry no user identity) can find the
  # right user. Nullable — most users have no subscription, and Postgres
  # unique indexes ignore NULLs so the many-null case is fine.
  #
  # The unique index is a security control, not just a data constraint: it
  # stops one Apple subscription entitling multiple Trays accounts.
  def change do
    alter table(:users) do
      add :apple_original_transaction_id, :string
    end

    create unique_index(:users, [:apple_original_transaction_id])
  end
end
