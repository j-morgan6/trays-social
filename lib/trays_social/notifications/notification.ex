defmodule TraysSocial.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :type, :string
    field :read_at, :utc_datetime

    belongs_to :user, TraysSocial.Accounts.User
    belongs_to :actor, TraysSocial.Accounts.User
    belongs_to :post, TraysSocial.Posts.Post

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:type, :user_id, :actor_id, :post_id, :read_at])
    |> validate_required([:type, :user_id, :actor_id])
    |> validate_inclusion(:type, ~w(like comment follow))
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:actor_id)
    |> foreign_key_constraint(:post_id)
  end
end
