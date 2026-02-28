defmodule TraysSocial.Posts.PostPhoto do
  use Ecto.Schema
  import Ecto.Changeset

  schema "post_photos" do
    field :url, :string
    field :position, :integer

    belongs_to :post, TraysSocial.Posts.Post

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(photo, attrs) do
    photo
    |> cast(attrs, [:url, :position, :post_id])
    |> validate_required([:url, :position])
  end
end
