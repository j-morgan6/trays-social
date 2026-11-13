defmodule TraysSocialWeb.TrayFormattingTest do
  # W246: My Tray copy matches iOS MyTrayCopy (W245).
  use ExUnit.Case, async: true

  import TraysSocialWeb.TrayFormatting

  doctest TraysSocialWeb.TrayFormatting

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

    # D126: the shared vectors from the iOS RecipeTitle tests
    # (RecipeDetailCopyTests.swift, D125, and the "Sesame chicken thighs"
    # caption from RecipeEditorTests.swift). A change here needs the matching
    # change there.
    test "matches every shared iOS vector" do
      vectors = [
        {"Sesame chicken. Crisp skin.", "Sesame chicken"},
        {"Weeknight dal\nRoast it hot.", "Weeknight dal"},
        {"Wait... it's good", "Wait"},
        {"  Weeknight dal  ", "Weeknight dal"},
        {"Mrs. Smith's pie", "Mrs. Smith's pie"},
        {"mrs. smith's pie", "mrs. smith's pie"},
        {"St. Louis ribs!", "St. Louis ribs"},
        {"J. Kenji's eggs", "J. Kenji's eggs"},
        {"Dr.", "Dr"},
        {"Mrs. Smith's pie. Flaky crust.", "Mrs. Smith's pie"},
        {"1.5 hour brisket", "1.5 hour brisket"},
        {"3.5oz steak. Rare.", "3.5oz steak"},
        {"Sesame chicken thighs\nWe make this most Tuesdays", "Sesame chicken thighs"},
        {nil, "Untitled recipe"},
        {"   ", "Untitled recipe"},
        {"...", "Untitled recipe"},
        {"?! .", "Untitled recipe"}
      ]

      for {caption, title} <- vectors do
        assert post_title(%{caption: caption}) == title, "caption #{inspect(caption)}"
      end
    end

    test "any line break ends the title line" do
      assert post_title(%{caption: "Weeknight dal\r\nRoast it hot."}) == "Weeknight dal"
      assert post_title(%{caption: "Weeknight dal\u2028Roast it hot."}) == "Weeknight dal"
    end

    test "a non-breaking space after a period ends the sentence" do
      assert post_title(%{caption: "Pie.\u00A0Crust."}) == "Pie"
    end

    test "a dotted multi-initial ends the title at its last period" do
      assert post_title(%{caption: "U.S. style ribs"}) == "U.S"
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
end
