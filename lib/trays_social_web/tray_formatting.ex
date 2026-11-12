defmodule TraysSocialWeb.TrayFormatting do
  @moduledoc """
  Pure copy for web My Tray and the profile page (W246). The header line and
  the recipe count mirror the iOS `MyTrayCopy.swift` from W245.
  """

  @doc """
  The line under the My Tray title: "7 recipes · 8 saved", or the new-user
  line when the tray is empty.

      iex> header_subtitle(7, 8)
      "7 recipes · 8 saved"
  """
  @spec header_subtitle(non_neg_integer(), non_neg_integer()) :: String.t()
  def header_subtitle(0, 0), do: "Recipes you post and save live here."
  def header_subtitle(recipes, saved), do: "#{recipe_count(recipes)} · #{saved} saved"

  @doc ~s("No recipes yet", "1 recipe" or "N recipes".)
  @spec recipe_count(non_neg_integer()) :: String.t()
  def recipe_count(0), do: "No recipes yet"
  def recipe_count(1), do: "1 recipe"
  def recipe_count(count), do: "#{count} recipes"

  @doc """
  When a recipe was saved, for the Saved card byline.

      iex> saved_on(~U[2026-11-11 09:00:00Z])
      "Saved Nov 11"
  """
  @spec saved_on(DateTime.t()) :: String.t()
  def saved_on(datetime), do: "Saved " <> Calendar.strftime(datetime, "%b %-d")

  @doc """
  A recipe's title from its caption: the first line or sentence, or
  "Untitled recipe" when the caption is empty.

      iex> post_title(%{caption: "Sunday short ribs. Braised for hours."})
      "Sunday short ribs"
  """
  @spec post_title(%{caption: String.t() | nil}) :: String.t()
  def post_title(%{caption: caption}) do
    case String.split(caption || "", ~r/[\n.!?]/, parts: 2, trim: true) do
      [title | _] -> title |> String.trim() |> untitled()
      _ -> "Untitled recipe"
    end
  end

  defp untitled(""), do: "Untitled recipe"
  defp untitled(title), do: title
end
