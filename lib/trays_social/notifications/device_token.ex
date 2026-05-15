defmodule TraysSocial.Notifications.DeviceToken do
  use Ecto.Schema
  import Ecto.Changeset

  schema "device_tokens" do
    field :token, :string
    field :platform, :string, default: "ios"

    belongs_to :user, TraysSocial.Accounts.User

    timestamps(type: :utc_datetime)
  end

  # D51: PushSender dispatches on `platform`. Constrain to the values the
  # dispatcher actually understands and cap the token length so a misbehaving
  # client cannot fill storage with arbitrary blobs.
  @valid_platforms ~w(ios android)
  @max_token_length 512

  @doc false
  def changeset(device_token, attrs) do
    device_token
    |> cast(attrs, [:token, :platform, :user_id])
    |> validate_required([:token, :user_id])
    |> validate_inclusion(:platform, @valid_platforms,
      message: "must be one of: #{Enum.join(@valid_platforms, ", ")}"
    )
    |> validate_length(:token, max: @max_token_length)
    |> unique_constraint(:token)
  end
end
