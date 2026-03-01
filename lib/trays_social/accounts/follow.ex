defmodule TraysSocial.Accounts.Follow do
  use Ecto.Schema
  import Ecto.Changeset

  schema "follows" do
    belongs_to :follower, TraysSocial.Accounts.User
    belongs_to :followed, TraysSocial.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(follow, attrs) do
    follow
    |> cast(attrs, [:follower_id, :followed_id])
    |> validate_required([:follower_id, :followed_id])
    |> validate_change(:followed_id, fn :followed_id, followed_id ->
      follower_id = get_field(follow, :follower_id)
      if follower_id && followed_id == follower_id, do: [followed_id: "cannot follow yourself"], else: []
    end)
    |> unique_constraint([:follower_id, :followed_id], name: :follows_follower_id_followed_id_index)
    |> foreign_key_constraint(:follower_id)
    |> foreign_key_constraint(:followed_id)
  end
end
