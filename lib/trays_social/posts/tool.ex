defmodule TraysSocial.Posts.Tool do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tools" do
    field :name, :string
    field :order, :integer

    belongs_to :post, TraysSocial.Posts.Post

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tool, attrs) do
    tool
    |> cast(attrs, [:name, :order, :post_id])
    |> validate_required([:name])
  end
end
