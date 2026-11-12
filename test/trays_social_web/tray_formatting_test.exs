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
  end
end
