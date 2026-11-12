defmodule TraysSocialWeb.SearchFormatting do
  @moduledoc """
  Pure formatting for the web Search page (W244), mirroring the iOS
  `SearchFormatting.swift` from W243 so both platforms word Search the same
  way: the ingredient summary card, the "Uses ..." line on a "You have
  everything" row, the Browse tile fill cycle and the Most saved ranks.
  """

  @ranked 3
  @fills [:cream, :amber, :mint]

  @doc """
  Title of the ingredient summary card. Up to three ingredients are listed;
  past that the card counts them.

      iex> summary_title(["chicken", "rice"])
      "With chicken and rice, you can make…"

      iex> summary_title(["a", "b", "c", "d"])
      "With your 4 ingredients"
  """
  @spec summary_title([String.t()]) :: String.t()
  def summary_title(terms) when length(terms) > 3, do: "With your #{length(terms)} ingredients"
  def summary_title(terms), do: "With #{list(terms)}, you can make…"

  @doc """
  Subtitle of the ingredient summary card.

      iex> summary_subtitle(2, 3)
      "2 ready now · 3 almost there"

      iex> summary_subtitle(0, 3)
      "Nothing complete yet · 3 almost there"
  """
  @spec summary_subtitle(non_neg_integer(), non_neg_integer()) :: String.t()
  def summary_subtitle(ready, almost) when ready > 0,
    do: "#{ready} ready now · #{almost} almost there"

  def summary_subtitle(_ready, almost), do: "Nothing complete yet · #{almost} almost there"

  @doc """
  The searched ingredients a recipe lists, in search order, as "Uses chicken,
  rice". A term counts when an ingredient name contains it, ignoring case.
  Nil when none match.
  """
  @spec uses_line([String.t()], [%{name: String.t()}]) :: String.t() | nil
  def uses_line(terms, ingredients) do
    names = Enum.map(ingredients, &String.downcase(&1.name))

    terms
    |> Enum.filter(&listed?(&1, names))
    |> uses_text()
  end

  @doc "Browse tiles cycle three warm fills: cream, amber, mint."
  @spec tile_fill(non_neg_integer()) :: :cream | :amber | :mint
  def tile_fill(index), do: Enum.at(@fills, rem(index, length(@fills)))

  @doc """
  Rank (1-based) of the first three posts of Most saved, keyed by post id.
  Computed on the posts alone, so ads in the grid never shift a rank.
  """
  @spec ranks([%{id: term()}]) :: %{term() => pos_integer()}
  def ranks(posts) do
    posts
    |> Enum.take(@ranked)
    |> Enum.with_index(1)
    |> Map.new(fn {post, rank} -> {post.id, rank} end)
  end

  defp list([one]), do: one
  defp list([first, second]), do: "#{first} and #{second}"
  defp list([first, second, third]), do: "#{first}, #{second}, and #{third}"

  defp listed?(term, names) do
    needle = String.downcase(term)
    Enum.any?(names, &String.contains?(&1, needle))
  end

  defp uses_text([]), do: nil
  defp uses_text(used), do: "Uses " <> Enum.join(used, ", ")
end
