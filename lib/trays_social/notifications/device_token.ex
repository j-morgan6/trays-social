defmodule TraysSocial.Notifications.DeviceToken do
  use Ecto.Schema
  import Ecto.Changeset

  schema "device_tokens" do
    field :token, :string
    field :platform, :string, default: "ios"

    belongs_to :user, TraysSocial.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(device_token, attrs) do
    device_token
    |> cast(attrs, [:token, :platform, :user_id])
    |> validate_required([:token, :user_id])
    |> unique_constraint(:token)
  end
end
