defmodule TraysSocialWeb.API.V1.JSON.CollectionJSON do
  @moduledoc """
  JSON rendering for collections (W172, Trays Plus) in API v1.

  Renders the summary maps produced by `TraysSocial.Collections`
  (`list_collections/1` / `collection_summary/1`).
  """

  def render(%{collection: collection, item_count: item_count, cover_photo_url: cover_photo_url}) do
    %{
      id: collection.id,
      name: collection.name,
      item_count: item_count,
      cover_photo_url: cover_photo_url,
      inserted_at: collection.inserted_at
    }
  end

  def render_list(summaries) do
    Enum.map(summaries, &render/1)
  end
end
