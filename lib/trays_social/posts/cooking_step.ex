defmodule TraysSocial.Posts.CookingStep do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cooking_steps" do
    field :description, :string
    field :order, :integer

    belongs_to :post, TraysSocial.Posts.Post

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(cooking_step, attrs) do
    cooking_step
    |> cast(attrs, [:description, :order, :post_id])
    |> validate_required([:description])
    |> validate_length(:description, max: 300)
  end
end
