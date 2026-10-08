defmodule TraysSocial.Posts.RecipeOpen do
  @moduledoc """
  When a user last opened a recipe. One row per (user, post), upserted on every
  open, so the table grows with distinct recipes rather than with views.
  `inserted_at` is the first open. Feeds Home's "Jump back in".
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "recipe_opens" do
    field :last_opened_at, :utc_datetime

    belongs_to :user, TraysSocial.Accounts.User
    belongs_to :post, TraysSocial.Posts.Post

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(recipe_open, attrs) do
    recipe_open
    |> cast(attrs, [:user_id, :post_id, :last_opened_at])
    |> validate_required([:user_id, :post_id, :last_opened_at])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:post_id)
    |> unique_constraint([:user_id, :post_id])
  end
end
