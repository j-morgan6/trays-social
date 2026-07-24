defmodule TraysSocial.Collections.CollectionItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "collection_items" do
    belongs_to :collection, TraysSocial.Collections.Collection
    belongs_to :post, TraysSocial.Posts.Post

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(collection_item, attrs) do
    collection_item
    |> cast(attrs, [:collection_id, :post_id])
    |> validate_required([:collection_id, :post_id])
    |> foreign_key_constraint(:collection_id)
    |> foreign_key_constraint(:post_id)
    |> unique_constraint([:collection_id, :post_id])
  end
end
