defmodule TraysSocial.Posts.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :type, :string, default: "recipe"
    field :photo_url, :string
    field :caption, :string
    field :cooking_time_minutes, :integer
    field :servings, :integer
    field :like_count, :integer, default: 0
    field :comment_count, :integer, default: 0
    field :deleted_at, :utc_datetime
    field :removed_at, :utc_datetime
    field :removed_reason, :string

    belongs_to :user, TraysSocial.Accounts.User
    belongs_to :removed_by, TraysSocial.Accounts.User

    has_many :ingredients, TraysSocial.Posts.Ingredient
    has_many :tools, TraysSocial.Posts.Tool
    has_many :cooking_steps, TraysSocial.Posts.CookingStep
    has_many :post_tags, TraysSocial.Posts.PostTag
    has_many :post_photos, TraysSocial.Posts.PostPhoto, preload_order: [asc: :position]
    has_many :post_likes, TraysSocial.Posts.PostLike
    has_many :comments, TraysSocial.Posts.Comment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:type, :photo_url, :caption, :cooking_time_minutes, :servings, :user_id])
    |> validate_required([:photo_url, :user_id])
    |> validate_inclusion(:type, ~w(recipe post))
    |> validate_length(:caption, max: 500)
    |> validate_number(:servings, greater_than: 0)
    |> validate_recipe_fields()
    |> foreign_key_constraint(:user_id)
  end

  defp validate_recipe_fields(changeset) do
    if get_field(changeset, :type) == "recipe" do
      changeset
      |> validate_required([:cooking_time_minutes])
      |> validate_number(:cooking_time_minutes, greater_than: 0)
    else
      changeset
    end
  end
end
