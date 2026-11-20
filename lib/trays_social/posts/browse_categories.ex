defmodule TraysSocial.Posts.BrowseCategories do
  @moduledoc """
  Fixed Browse tiles for Search. Each tile is a saved search query. Defined on
  the server so the set can change without an app release; clients show
  `label`, and the iOS client is expected to map known keys to localized labels.

  `q` is either one search term or a list of terms matched with OR, each with
  the same caption / ingredient / tag semantics as typed search. A `tag` tile
  matches that exact tag only.

  Category keys arriving from clients are only ever looked up in this fixed
  list; a key is never used to build a query directly, and the terms come from
  this list, never from params.
  """

  @categories [
    %{key: "quick_dinners", label: "Quick dinners", q: nil, tag: nil, max_cooking_time: 30},
    %{key: "chicken", label: "Chicken", q: "chicken", tag: nil, max_cooking_time: nil},
    %{key: "vegetarian", label: "Vegetarian", q: nil, tag: "vegetarian", max_cooking_time: nil},
    %{
      key: "beef",
      label: "Beef",
      q: ["beef", "steak", "brisket", "ground beef"],
      tag: nil,
      max_cooking_time: nil
    },
    %{
      key: "pork",
      label: "Pork",
      q: ["pork", "bacon", "ham", "sausage", "chorizo", "prosciutto"],
      tag: nil,
      max_cooking_time: nil
    },
    %{key: "baking", label: "Baking", q: nil, tag: "baking", max_cooking_time: nil}
  ]

  @doc "All Browse categories, in display order."
  def list, do: @categories

  @doc "The category for `key`, or nil when the key is unknown."
  def fetch(key) when is_binary(key), do: Enum.find(@categories, &(&1.key == key))
  def fetch(_), do: nil

  @doc "The client-facing shape of a category."
  def to_json(category), do: %{key: category.key, label: category.label}
end
