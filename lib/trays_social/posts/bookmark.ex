defmodule TraysSocial.Posts.Bookmark do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bookmarks" do
    belongs_to :user, TraysSocial.Accounts.User
    belongs_to :post, TraysSocial.Posts.Post

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(bookmark, attrs) do
    bookmark
    |> cast(attrs, [:user_id, :post_id])
    |> validate_required([:user_id, :post_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:post_id)
    |> unique_constraint([:user_id, :post_id])
  end
end
