defmodule TraysSocial.Collections.Collection do
  use Ecto.Schema
  import Ecto.Changeset

  schema "collections" do
    field :name, :string

    belongs_to :user, TraysSocial.Accounts.User
    has_many :collection_items, TraysSocial.Collections.CollectionItem

    timestamps(type: :utc_datetime)
  end

  def changeset(collection, attrs) do
    collection
    |> cast(attrs, [:name, :user_id])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, max: 60)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:name, name: :collections_user_id_name_index)
  end

  # Rename never re-casts :user_id — ownership is creation-only.
  def rename_changeset(collection, attrs) do
    collection
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, max: 60)
    |> unique_constraint(:name, name: :collections_user_id_name_index)
  end
end
