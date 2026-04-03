defmodule TraysSocial.Repo.Migrations.CreateDeviceTokens do
  use Ecto.Migration

  def change do
    create table(:device_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :text, null: false
      add :platform, :string, null: false, default: "ios"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:device_tokens, [:token])
    create index(:device_tokens, [:user_id])
  end
end
