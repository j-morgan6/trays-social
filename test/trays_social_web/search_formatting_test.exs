defmodule TraysSocialWeb.SearchFormattingTest do
  use ExUnit.Case, async: true

  alias TraysSocialWeb.SearchFormatting

  doctest SearchFormatting, import: true

  defp ingredients(names), do: Enum.map(names, &%{name: &1})

  test "the summary title lists up to three ingredients" do
    assert SearchFormatting.summary_title(["chicken"]) == "With chicken, you can make…"

    assert SearchFormatting.summary_title(["chicken", "rice"]) ==
             "With chicken and rice, you can make…"

    assert SearchFormatting.summary_title(["chicken", "rice", "garlic"]) ==
             "With chicken, rice, and garlic, you can make…"
  end

  test "the summary title counts the ingredients past three" do
    assert SearchFormatting.summary_title(~w(a b c d)) == "With your 4 ingredients"
    assert SearchFormatting.summary_title(~w(a b c d e f g h i j)) == "With your 10 ingredients"
  end

  test "the summary subtitle counts ready and almost-there recipes" do
    assert SearchFormatting.summary_subtitle(2, 3) == "2 ready now · 3 almost there"
    assert SearchFormatting.summary_subtitle(1, 0) == "1 ready now · 0 almost there"
  end

  test "the summary subtitle says nothing is complete when no recipe is ready" do
    assert SearchFormatting.summary_subtitle(0, 4) == "Nothing complete yet · 4 almost there"
  end

  test "the uses line lists matched terms in search order, ignoring case" do
    list = ingredients(["Brown Rice", "chicken thighs", "garlic"])

    assert SearchFormatting.uses_line(["chicken", "RICE"], list) == "Uses chicken, RICE"
  end

  test "the uses line is nil when no term matches" do
    assert SearchFormatting.uses_line(["tofu"], ingredients(["rice"])) == nil
    assert SearchFormatting.uses_line(["tofu"], []) == nil
  end

  test "tile fills cycle cream, amber, mint" do
    assert Enum.map(0..6, &SearchFormatting.tile_fill/1) ==
             [:cream, :amber, :mint, :cream, :amber, :mint, :cream]
  end

  test "ranks cover the first three posts only" do
    posts = Enum.map([10, 20, 30, 40], &%{id: &1})

    assert SearchFormatting.ranks(posts) == %{10 => 1, 20 => 2, 30 => 3}
    assert SearchFormatting.ranks([]) == %{}
  end
end
