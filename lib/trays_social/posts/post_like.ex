defmodule TraysSocial.Posts.PostLike do
  use Ecto.Schema
  import Ecto.Changeset

  schema "post_likes" do
    belongs_to :post, TraysSocial.Posts.Post
    belongs_to :user, TraysSocial.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(post_like, attrs) do
    post_like
    |> cast(attrs, [:post_id, :user_id])
    |> validate_required([:post_id, :user_id])
    |> unique_constraint([:post_id, :user_id], name: :post_likes_post_id_user_id_index)
    |> foreign_key_constraint(:post_id)
    |> foreign_key_constraint(:user_id)
  end
end
