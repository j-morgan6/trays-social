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

  # D126: the one web copy of the recipe title rule. It must match the iOS
  # RecipeTitle (Extensions/RecipeTitle.swift, D125) caption for caption, so
  # it is the same plain left-to-right scan, and the shared vectors in
  # tray_formatting_test.exs mirror RecipeDetailCopyTests.swift and
  # RecipeEditorTests.swift:
  #
  # 1. Trim the caption and take the text before its first line break.
  # 2. The title ends at the first ".", "!" or "?" followed by whitespace or
  #    the end of that line. A period never ends it when the word before it
  #    (back to the previous whitespace, leading non-letters dropped) is a
  #    known abbreviation, matched case-insensitively, or a single-letter
  #    initial. A period followed by anything else (1.5, 3.5oz) never ends it.
  # 3. Trailing terminators and whitespace are dropped; empty means fallback.
  #
  # The title is always a prefix of the trimmed caption, which post_note/1
  # relies on. Each step walks the graphemes once and no regex spans the
  # caption (letter?/1 tests a single grapheme), so a long caption costs
  # linear time.
  @abbreviations MapSet.new(~w(mr mrs ms dr st mt jr sr prof vs approx no))
  @terminators [".", "!", "?"]
  @newlines ["\n", "\r", "\r\n", "\v", "\f", "\u0085", "\u2028", "\u2029"]
  @note_trim [" ", "\n", "\t", ".", "!", "?"]

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
      |> Enum.drop_while(&(&1 in @note_trim))
      |> Enum.reverse()
      |> Enum.drop_while(&(&1 in @note_trim))
      |> Enum.reverse()
      |> Enum.join()
    end
  end

  defp trimmed(nil), do: ""
  defp trimmed(caption) when is_binary(caption), do: String.trim(caption)

  defp first_sentence(raw) do
    raw
    |> String.graphemes()
    |> Enum.take_while(&(&1 not in @newlines))
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

  # The word before a period: a known abbreviation or a single-letter
  # initial keeps it. `word` is reversed.
  defp keeps_period?(word) do
    letters =
      word
      |> Enum.reverse()
      |> Enum.drop_while(&(not letter?(&1)))
      |> Enum.join()
      |> String.downcase()

    String.length(letters) == 1 or MapSet.member?(@abbreviations, letters)
  end

  defp whitespace?(char), do: String.trim(char) == ""
  defp letter?(char), do: String.match?(char, ~r/\A\p{L}/u)
end
