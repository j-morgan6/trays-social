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

  # D126: the one web copy of the recipe title rule; iOS RecipeTitle
  # (Extensions/RecipeTitle.swift, D125) is the other. The rule is defined by
  # ios/TraysSocial/TraysSocialTests/Fixtures/recipe-title-vectors.json (W267):
  # every title and note there, plus its abbreviation, whitespace and
  # line-break lists, is asserted against this module by
  # tray_formatting_test.exs and against RecipeTitle by
  # RecipeTitleVectorTests.swift. Change the rule by editing that file and
  # both implementations together.
  #
  # Whitespace and line breaks are the explicit lists below, never String.trim
  # or a Unicode table, so the rule does not move with the Elixir/OTP version.
  # The title is always a prefix of the trimmed caption, which post_note/1
  # relies on. Each step walks the graphemes once and no regex spans the
  # caption (letter?/1 tests a single grapheme), so a long caption costs
  # linear time.
  @abbreviations MapSet.new(~w(mr mrs ms dr st mt jr sr prof vs approx no))
  @terminators [".", "!", "?"]
  @line_breaks ["\n", "\r", "\r\n", "\v", "\f", "\u0085", "\u2028", "\u2029"]
  @whitespace [" ", "\t", "\u00A0", "\u1680"] ++
                Enum.map(0x2000..0x200A, &<<&1::utf8>>) ++
                ["\u202F", "\u205F", "\u3000"] ++ @line_breaks
  @note_trim @terminators ++ @whitespace

  @doc """
  A recipe's title from its caption: the first line or sentence, or
  "Untitled recipe" when the caption has none. A period after an
  abbreviation or an initial does not end the sentence.

      iex> post_title(%{caption: "Sunday short ribs. Braised for hours."})
      "Sunday short ribs"

      iex> post_title(%{caption: "Mrs. Smith's pie. Flaky crust."})
      "Mrs. Smith's pie"
  """
  @spec post_title(%{caption: String.t() | nil}) :: String.t()
  def post_title(%{caption: caption}), do: caption_title(caption)

  @doc """
  The title rule over a bare caption, with the fallback a surface uses when
  the caption has no title (the editor preview passes "").

      iex> caption_title("St. Louis ribs!", "")
      "St. Louis ribs"

      iex> caption_title("...", "")
      ""
  """
  @spec caption_title(String.t() | nil, String.t()) :: String.t()
  def caption_title(caption, fallback \\ "Untitled recipe") do
    case first_sentence(trimmed(caption)) do
      "" -> fallback
      title -> title
    end
  end

  @doc """
  The cook's note: the caption after its title, without the joining
  punctuation. Empty when the caption is a single sentence.

      iex> post_note(%{caption: "Mrs. Smith's pie. Flaky crust."})
      "Flaky crust"

      iex> post_note(%{caption: "Mrs. Smith's pie"})
      ""
  """
  @spec post_note(%{caption: String.t() | nil}) :: String.t()
  def post_note(%{caption: caption}) do
    raw = trimmed(caption)
    title = first_sentence(raw)

    if title == "" or byte_size(raw) <= byte_size(title) do
      ""
    else
      raw
      |> binary_part(byte_size(title), byte_size(raw) - byte_size(title))
      |> String.graphemes()
      |> trim_graphemes(@note_trim)
    end
  end

  @doc false
  # The rule's lists, for the vector-file test only (W267).
  @spec title_rule_sets() :: %{
          abbreviations: [String.t()],
          whitespace: [String.t()],
          line_breaks: [String.t()]
        }
  def title_rule_sets do
    %{
      abbreviations: MapSet.to_list(@abbreviations),
      whitespace: @whitespace,
      line_breaks: @line_breaks
    }
  end

  defp trimmed(nil), do: ""

  defp trimmed(caption) when is_binary(caption),
    do: caption |> String.graphemes() |> trim_graphemes(@whitespace)

  defp trim_graphemes(graphemes, set) do
    graphemes
    |> Enum.drop_while(&(&1 in set))
    |> Enum.reverse()
    |> Enum.drop_while(&(&1 in set))
    |> Enum.reverse()
    |> Enum.join()
  end

  defp first_sentence(raw) do
    raw
    |> String.graphemes()
    |> Enum.take_while(&(&1 not in @line_breaks))
    |> scan([], [])
    |> Enum.drop_while(&(&1 in @terminators or whitespace?(&1)))
    |> Enum.reverse()
    |> Enum.join()
  end

  # Walks the line, keeping the title so far and the current word, both
  # reversed. Returns the reversed title at the first sentence end.
  defp scan([], title, _word), do: title

  defp scan([char | rest], title, word) when char in @terminators do
    ends_sentence? = sentence_break?(rest) and not (char == "." and keeps_period?(word))

    if ends_sentence?, do: title, else: scan(rest, [char | title], [char | word])
  end

  defp scan([char | rest], title, word) do
    if whitespace?(char),
      do: scan(rest, [char | title], []),
      else: scan(rest, [char | title], [char | word])
  end

  defp sentence_break?([]), do: true
  defp sentence_break?([next | _]), do: whitespace?(next)

  # The word before a period (`word` is reversed), leading non-letters
  # dropped, keeps it when it is a known abbreviation in any case or a dotted
  # initial: single letters each followed by a period, so "J", "U.S" and
  # "e.g" keep it and "Ph.D" does not.
  defp keeps_period?(word) do
    letters = word |> Enum.reverse() |> Enum.drop_while(&(not letter?(&1)))

    dotted_initial?(letters) or
      MapSet.member?(@abbreviations, letters |> Enum.join() |> String.downcase())
  end

  defp dotted_initial?([letter]), do: letter?(letter)
  defp dotted_initial?([letter, "." | rest]), do: letter?(letter) and dotted_initial?(rest)
  defp dotted_initial?(_letters), do: false

  defp whitespace?(char), do: char in @whitespace
  defp letter?(char), do: String.match?(char, ~r/\A\p{L}/u)
end
