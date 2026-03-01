defmodule TraysSocial.Posts.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "post_comments" do
    field :body, :string
    field :deleted_at, :utc_datetime

    belongs_to :post, TraysSocial.Posts.Post
    belongs_to :user, TraysSocial.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :post_id, :user_id])
    |> validate_required([:body, :post_id, :user_id])
    |> validate_length(:body, min: 1, max: 1000)
    |> foreign_key_constraint(:post_id)
    |> foreign_key_constraint(:user_id)
  end
end
