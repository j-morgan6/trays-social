defmodule TraysSocialWeb.TrayFormattingTest do
  # W246: My Tray copy matches iOS MyTrayCopy (W245).
  use ExUnit.Case, async: true

  import TraysSocialWeb.TrayFormatting

  doctest TraysSocialWeb.TrayFormatting

  # W267: the shared title and note vectors. RecipeTitleVectorTests.swift
  # reads the same file, so both platforms are held to one list.
  @vectors Path.expand(
             "../../ios/TraysSocial/TraysSocialTests/Fixtures/recipe-title-vectors.json",
             __DIR__
           )

  defp read_vectors(path), do: path |> File.read!() |> Jason.decode!()

  # Everything wrong with a decoded vector file, so a missing tag, an empty
  # list or a malformed vector fails loudly instead of looping over nothing.
  defp vector_file_problems(file) do
    vectors = Map.get(file, "vectors")
    tags = file |> Map.get("rule_tags", %{}) |> Map.keys() |> MapSet.new()

    cond do
      not is_list(vectors) or vectors == [] ->
        ["no vectors"]

      MapSet.size(tags) == 0 ->
        ["no rule tags"]

      true ->
        shape_problems(vectors, tags) ++
          tag_problems(vectors, tags) ++
          abbreviation_problems(vectors, Map.get(file, "abbreviations", []))
    end
  end

  defp shape_problems(vectors, tags) do
    for vector <- vectors, problem = vector_problem(vector, tags), do: problem
  end

  defp vector_problem(
         %{"caption" => caption, "title" => title, "note" => note, "rule" => rule} = v
       )
       when (is_binary(caption) or is_nil(caption)) and is_binary(title) and is_binary(note) and
              is_binary(rule) and map_size(v) == 4,
       do: nil

  defp vector_problem(vector), do: "malformed vector #{inspect(vector)}"

  defp vector_problem(vector, tags) do
    case vector_problem(vector) do
      nil ->
        if MapSet.member?(tags, vector["rule"]), do: nil, else: "unknown rule #{vector["rule"]}"

      problem ->
        problem
    end
  end

  defp tag_problems(vectors, tags) do
    used = MapSet.new(vectors, & &1["rule"])
    for tag <- MapSet.difference(tags, used), do: "no vector for rule #{tag}"
  end

  defp abbreviation_problems(vectors, abbreviations) do
    captions =
      for %{"rule" => rule, "caption" => c} <- vectors,
          rule in ["abbreviation", "no_tradeoff"] and is_binary(c),
          do: String.downcase(c)

    for abbreviation <- abbreviations,
        not Enum.any?(captions, &abbreviated?(&1, abbreviation)),
        do: "no vector for abbreviation #{abbreviation}"
  end

  # The caption has the abbreviation as a word, followed by its period.
  defp abbreviated?(caption, abbreviation) do
    caption
    |> String.split()
    |> Enum.any?(&(String.trim_leading(&1, "(") == abbreviation <> "."))
  end

  describe "header_subtitle/2" do
    test "counts recipes and saves" do
      assert header_subtitle(7, 8) == "7 recipes · 8 saved"
      assert header_subtitle(1, 0) == "1 recipe · 0 saved"
      assert header_subtitle(0, 3) == "No recipes yet · 3 saved"
    end

    test "an empty tray gets the new-user line" do
      assert header_subtitle(0, 0) == "Recipes you post and save live here."
    end
  end

  describe "recipe_count/1" do
    test "words zero, one and many" do
      assert recipe_count(0) == "No recipes yet"
      assert recipe_count(1) == "1 recipe"
      assert recipe_count(40) == "40 recipes"
    end
  end

  describe "saved_on/1" do
    test "drops the leading zero from the day" do
      assert saved_on(~U[2026-03-04 12:00:00Z]) == "Saved Mar 4"
    end
  end

  describe "post_title/1" do
    test "takes the first line or sentence, or falls back" do
      assert post_title(%{caption: "Short ribs\nBraised"}) == "Short ribs"
      assert post_title(%{caption: "  "}) == "Untitled recipe"
      assert post_title(%{caption: nil}) == "Untitled recipe"
    end

    test "keeps a period after an abbreviation" do
      assert post_title(%{caption: "Mrs. Smith's pie"}) == "Mrs. Smith's pie"
      assert post_title(%{caption: "mrs. smith's pie"}) == "mrs. smith's pie"
      assert post_title(%{caption: "St. Louis ribs!"}) == "St. Louis ribs"
      assert post_title(%{caption: "J. Kenji's eggs"}) == "J. Kenji's eggs"
      assert post_title(%{caption: "Dr."}) == "Dr"
      assert post_title(%{caption: "Approx. 2 hour chili"}) == "Approx. 2 hour chili"
      assert post_title(%{caption: "Pie (Dr. Lee's)"}) == "Pie (Dr. Lee's)"
    end

    test "ends at the sentence after an abbreviation" do
      assert post_title(%{caption: "Mrs. Smith's pie. Flaky crust."}) == "Mrs. Smith's pie"
      assert post_title(%{caption: "Mt. Fuji rolls! Eat cold."}) == "Mt. Fuji rolls"
    end

    test "never ends inside a number" do
      assert post_title(%{caption: "1.5 hour brisket"}) == "1.5 hour brisket"
      assert post_title(%{caption: "3.5oz steak. Rare."}) == "3.5oz steak"
    end

    test "uses Untitled recipe for nil, blank and punctuation-only captions" do
      assert post_title(%{caption: nil}) == "Untitled recipe"
      assert post_title(%{caption: "   "}) == "Untitled recipe"
      assert post_title(%{caption: "..."}) == "Untitled recipe"
      assert post_title(%{caption: "?! ."}) == "Untitled recipe"
    end

    test "any line break ends the title line" do
      assert post_title(%{caption: "Weeknight dal\r\nRoast it hot."}) == "Weeknight dal"
      assert post_title(%{caption: "Weeknight dal\u2028Roast it hot."}) == "Weeknight dal"
    end

    test "a non-breaking space after a period ends the sentence" do
      assert post_title(%{caption: "Pie.\u00A0Crust."}) == "Pie"
    end

    test "a dotted initial keeps its period" do
      assert post_title(%{caption: "U.S. style ribs"}) == "U.S. style ribs"
      assert post_title(%{caption: "e.g. tacos"}) == "e.g. tacos"
      assert post_title(%{caption: "Made in the U.S."}) == "Made in the U.S"
      assert post_title(%{caption: "Ph.D. level brisket"}) == "Ph.D"
    end

    test "a long caption with no terminator is handled quickly" do
      caption = String.duplicate("brisket and greens ", 10_000)

      {micros, title} = :timer.tc(fn -> post_title(%{caption: caption}) end)

      assert title == String.trim(caption)
      assert micros < 2_000_000
    end
  end

  describe "surfaces" do
    # D126: explore, home and notifications title a recipe by the shared rule.
    test "every web surface that titles a recipe uses the shared rule" do
      post = %{caption: "Mrs. Smith's pie. Flaky crust."}

      assert TraysSocialWeb.ExploreLive.Index.post_title(post) == "Mrs. Smith's pie"
      assert TraysSocialWeb.HomeLive.Index.post_title(post) == "Mrs. Smith's pie"
      assert TraysSocialWeb.NotificationsLive.Index.post_title(post) == "Mrs. Smith's pie"
      assert TraysSocialWeb.NotificationsLive.Index.post_title(nil) == nil
    end
  end

  describe "caption_title/2" do
    test "uses the given fallback when there is no title" do
      assert caption_title("...", "") == ""
      assert caption_title(nil, "") == ""
      assert caption_title("Mrs. Smith's pie. Flaky crust.", "") == "Mrs. Smith's pie"
    end
  end

  describe "post_note/1" do
    test "is the caption after the title" do
      assert post_note(%{caption: "Mrs. Smith's pie. Flaky crust."}) == "Flaky crust"
      assert post_note(%{caption: "St. Louis ribs! Low and slow."}) == "Low and slow"

      assert post_note(%{caption: "Sesame chicken. Crisp skin, sticky glaze!"}) ==
               "Crisp skin, sticky glaze"

      assert post_note(%{caption: "Sesame chicken\nRoast it hot."}) == "Roast it hot"
    end

    test "is empty for a one-sentence caption or no caption" do
      assert post_note(%{caption: "Mrs. Smith's pie"}) == ""
      assert post_note(%{caption: "Sesame chicken."}) == ""
      assert post_note(%{caption: "..."}) == ""
      assert post_note(%{caption: nil}) == ""
    end
  end

  describe "recipe-title-vectors.json" do
    test "the vector file parses, is not empty and covers every rule tag and abbreviation" do
      file = read_vectors(@vectors)

      assert vector_file_problems(file) == []
      assert file["fallback"] == "Untitled recipe"

      sets = title_rule_sets()
      assert Enum.sort(file["abbreviations"]) == Enum.sort(sets.abbreviations)
      assert length(file["abbreviations"]) == 12
      assert Enum.sort(file["whitespace"]) == Enum.sort(sets.whitespace)
      assert Enum.sort(file["line_breaks"]) == Enum.sort(sets.line_breaks)
    end

    @tag :tmp_dir
    test "a missing, unparsable, empty or incomplete vector file is a failure, not zero vectors",
         %{tmp_dir: tmp_dir} do
      assert_raise File.Error, fn -> read_vectors(@vectors <> ".missing") end

      unparsable = Path.join(tmp_dir, "recipe-title-vectors.json")
      File.write!(unparsable, "{")
      assert_raise Jason.DecodeError, fn -> read_vectors(unparsable) end

      file = read_vectors(@vectors)
      assert vector_file_problems(%{file | "vectors" => []}) == ["no vectors"]
      assert vector_file_problems(Map.delete(file, "vectors")) == ["no vectors"]

      no_dotted = Enum.reject(file["vectors"], &(&1["rule"] == "dotted_initial"))

      assert "no vector for rule dotted_initial" in vector_file_problems(%{
               file
               | "vectors" => no_dotted
             })

      no_vs = Enum.reject(file["vectors"], &(is_binary(&1["caption"]) and &1["caption"] =~ "vs."))
      assert "no vector for abbreviation vs" in vector_file_problems(%{file | "vectors" => no_vs})
    end

    test "every vector has caption, title, note and rule" do
      file = read_vectors(@vectors)

      for vector <- file["vectors"] do
        assert vector_problem(vector, MapSet.new(Map.keys(file["rule_tags"]))) == nil
      end

      [vector | _] = file["vectors"]
      assert vector_problem(Map.delete(vector, "note")) =~ "malformed vector"
      assert vector_problem(%{vector | "title" => nil}) =~ "malformed vector"
    end

    test "matches every vector in recipe-title-vectors.json" do
      file = read_vectors(@vectors)
      assert [_ | _] = file["vectors"]

      for %{"caption" => caption, "title" => title, "note" => note} <- file["vectors"] do
        assert post_title(%{caption: caption}) == title, "title of #{inspect(caption)}"
        assert caption_title(caption, file["fallback"]) == title, "title of #{inspect(caption)}"
        assert post_note(%{caption: caption}) == note, "note of #{inspect(caption)}"
      end
    end
  end
end
