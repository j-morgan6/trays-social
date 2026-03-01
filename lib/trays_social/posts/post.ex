defmodule TraysSocial.Posts.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :photo_url, :string
    field :caption, :string
    field :cooking_time_minutes, :integer
    field :servings, :integer
    field :difficulty, :string
    field :like_count, :integer, default: 0
    field :deleted_at, :utc_datetime

    belongs_to :user, TraysSocial.Accounts.User

    has_many :ingredients, TraysSocial.Posts.Ingredient
    has_many :tools, TraysSocial.Posts.Tool
    has_many :cooking_steps, TraysSocial.Posts.CookingStep
    has_many :post_tags, TraysSocial.Posts.PostTag
    has_many :post_photos, TraysSocial.Posts.PostPhoto, preload_order: [asc: :position]
    has_many :post_likes, TraysSocial.Posts.PostLike

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:photo_url, :caption, :cooking_time_minutes, :servings, :difficulty, :user_id])
    |> validate_required([:photo_url, :caption, :cooking_time_minutes, :user_id])
    |> validate_length(:caption, max: 500)
    |> validate_number(:cooking_time_minutes, greater_than: 0)
    |> validate_number(:servings, greater_than: 0)
    |> validate_inclusion(:difficulty, ~w(easy medium hard))
    |> foreign_key_constraint(:user_id)
  end
end
