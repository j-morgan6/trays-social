defmodule TraysSocial.Accounts.UserBlock do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_blocks" do
    belongs_to :blocker, TraysSocial.Accounts.User
    belongs_to :blocked, TraysSocial.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(block, attrs) do
    block
    |> cast(attrs, [:blocker_id, :blocked_id])
    |> validate_required([:blocker_id, :blocked_id])
    |> validate_not_self_block()
    |> unique_constraint([:blocker_id, :blocked_id])
    |> foreign_key_constraint(:blocker_id)
    |> foreign_key_constraint(:blocked_id)
  end

  defp validate_not_self_block(changeset) do
    blocker = get_field(changeset, :blocker_id)
    blocked = get_field(changeset, :blocked_id)

    if blocker && blocked && blocker == blocked do
      add_error(changeset, :blocked_id, "cannot block yourself")
    else
      changeset
    end
  end
end
