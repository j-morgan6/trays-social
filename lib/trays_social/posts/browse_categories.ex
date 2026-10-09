defmodule TraysSocial.Posts.BrowseCategories do
  @moduledoc """
  Fixed Browse tiles for Search. Each tile is a saved search query. Defined on
  the server so the set can change without an app release; clients show
  `label`, and the iOS client is expected to map known keys to localized labels.

  Category keys arriving from clients are only ever looked up in this fixed
  list; a key is never used to build a query directly.
  """

  @categories [
    %{key: "quick_dinners", label: "Quick dinners", q: nil, tag: nil, max_cooking_time: 30},
    %{key: "chicken", label: "Chicken", q: "chicken", tag: nil, max_cooking_time: nil},
    %{key: "pasta", label: "Pasta", q: "pasta", tag: nil, max_cooking_time: nil},
    %{key: "breakfast", label: "Breakfast", q: nil, tag: "breakfast", max_cooking_time: nil},
    %{key: "baking", label: "Baking", q: nil, tag: "baking", max_cooking_time: nil},
    %{key: "soups", label: "Soups", q: "soup", tag: nil, max_cooking_time: nil}
  ]

  @doc "All Browse categories, in display order."
  def list, do: @categories

  @doc "The category for `key`, or nil when the key is unknown."
  def fetch(key) when is_binary(key), do: Enum.find(@categories, &(&1.key == key))
  def fetch(_), do: nil

  @doc "The client-facing shape of a category."
  def to_json(category), do: %{key: category.key, label: category.label}
end
