defmodule TraysSocial.Posts.PostTag do
  use Ecto.Schema
  import Ecto.Changeset

  schema "post_tags" do
    field :tag, :string

    belongs_to :post, TraysSocial.Posts.Post

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post_tag, attrs) do
    post_tag
    |> cast(attrs, [:tag, :post_id])
    |> validate_required([:tag])
    |> update_change(:tag, &normalize_tag/1)
  end

  defp normalize_tag(tag) when is_binary(tag) do
    tag
    |> String.downcase()
    |> String.trim()
  end

  defp normalize_tag(tag), do: tag
end
