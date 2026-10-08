defmodule TraysSocial.Features do
  @moduledoc """
  Product feature flags that are not monetization. Backed by the same
  `config :trays_social, :features` keyword list (and `FEATURES_*` env vars)
  as `TraysSocial.Monetization`, with the same semantics: a missing key is off
  and only the literal `true` turns a flag on.
  """

  alias TraysSocial.Monetization

  @doc "Recipe-first navigation: Home / My Tray / Search, recipe-only posting."
  @spec recipe_first?() :: boolean()
  def recipe_first?, do: Monetization.feature_enabled?(:recipe_first)

  @doc """
  Flags the native app reads at launch from `GET /api/v1/features`.

  Only non-sensitive product flags belong here: the map is sent to every
  signed-in client.
  """
  @spec client_flags() :: %{recipe_first: boolean()}
  def client_flags, do: %{recipe_first: recipe_first?()}
end
