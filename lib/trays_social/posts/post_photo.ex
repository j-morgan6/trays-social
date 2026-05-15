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
    |> validate_url_scheme()
  end

  # D50: same scheme defense as Post.photo_url (D44). Photo URLs render in
  # every feed/post-detail view; rejecting javascript:/data:/vbscript:/file:
  # at the changeset closes the XSS sink for every caller (REST, LiveView,
  # internal). Whitelist http(s):// and app-relative /paths.
  defp validate_url_scheme(changeset) do
    validate_change(changeset, :url, fn :url, value ->
      cond do
        not is_binary(value) -> []
        value == "" -> []
        Regex.match?(~r{\Ahttps?://}i, value) -> []
        Regex.match?(~r{\A/[^/]}, value) -> []
        true -> [url: "must be an http(s) URL or app-relative path"]
      end
    end)
  end
end
