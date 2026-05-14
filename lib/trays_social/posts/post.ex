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

  # D44: :user_id is intentionally NOT in the cast list. Ownership FKs are
  # never set from user-controlled attrs — `Posts.create_post/2` writes the
  # field via `put_change` after authorization. validate_required still
  # enforces presence so an unbuilt %Post{} cannot be inserted without one.
  # Same defense lets `update_post(post, attrs)` accept user input safely:
  # even a request body claiming `{"user_id": <victim>}` is silently dropped.
  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:type, :photo_url, :caption, :cooking_time_minutes, :servings])
    |> validate_required([:photo_url, :user_id])
    |> validate_inclusion(:type, ~w(recipe post))
    |> validate_length(:caption, max: 500)
    |> validate_number(:servings, greater_than: 0)
    |> validate_photo_url()
    |> validate_recipe_fields()
    |> foreign_key_constraint(:user_id)
  end

  # D44: photo_url must be either an absolute http(s) URL (S3, CDN) or a
  # relative path served by this app (local /uploads). Anything with a
  # different scheme (`javascript:`, `data:`, `vbscript:`, `file:`, etc.)
  # would become stored XSS when rendered into an <a href>, an iOS
  # WKWebView, or any other interpreted context. Empty/nil falls through
  # to `validate_required` so this validator only fires when a value is
  # present.
  defp validate_photo_url(changeset) do
    validate_change(changeset, :photo_url, fn :photo_url, value ->
      cond do
        not is_binary(value) -> []
        value == "" -> []
        # Absolute http(s) URL — typical for S3/CDN-hosted photos.
        Regex.match?(~r{\Ahttps?://}i, value) -> []
        # App-relative path — local /uploads/... goes here. A leading
        # slash that isn't `//` keeps protocol-relative URLs out of this
        # branch (those would be ambiguous on platforms like iOS).
        Regex.match?(~r{\A/[^/]}, value) -> []
        true -> [photo_url: "must be an http(s) URL or app-relative path"]
      end
    end)
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
