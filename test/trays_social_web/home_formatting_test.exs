defmodule TraysSocialWeb.HomeFormattingTest do
  use ExUnit.Case, async: true

  alias TraysSocialWeb.HomeFormatting

  @now ~U[2026-11-12 18:00:00Z]

  # The age label and New rule for something posted `seconds` before @now.
  defp ago(seconds), do: @now |> DateTime.add(-seconds) |> HomeFormatting.time_ago(@now)
  defp new_after?(seconds), do: @now |> DateTime.add(-seconds) |> HomeFormatting.new?(@now)

  describe "greeting_kicker/1" do
    test "names the weekday and part of day" do
      assert HomeFormatting.greeting_kicker(~N[2026-11-12 18:30:00]) == "Thursday evening"
      assert HomeFormatting.greeting_kicker(~N[2026-11-09 08:00:00]) == "Monday morning"
      assert HomeFormatting.greeting_kicker(~N[2026-11-15 13:00:00]) == "Sunday afternoon"
    end

    test "day-part boundaries" do
      assert HomeFormatting.day_part(4) == "night"
      assert HomeFormatting.day_part(5) == "morning"
      assert HomeFormatting.day_part(11) == "morning"
      assert HomeFormatting.day_part(12) == "afternoon"
      assert HomeFormatting.day_part(16) == "afternoon"
      assert HomeFormatting.day_part(17) == "evening"
      assert HomeFormatting.day_part(21) == "evening"
      assert HomeFormatting.day_part(22) == "night"
      assert HomeFormatting.day_part(0) == "night"
    end
  end

  test "question/1 names the cook when there is a username" do
    assert HomeFormatting.question("ren") == "What are you cooking, ren?"
    assert HomeFormatting.question("") == "What are you cooking?"
    assert HomeFormatting.question(nil) == "What are you cooking?"
  end

  test "new?/2 is true for less than a day, including clock skew" do
    assert new_after?(24 * 3600 - 1)
    refute new_after?(24 * 3600)
    assert new_after?(-60)
  end

  test "cook_time_label/1 uses the canvas format" do
    assert HomeFormatting.cook_time_label(nil) == nil
    assert HomeFormatting.cook_time_label(0) == nil
    assert HomeFormatting.cook_time_label(25) == "25 min"
    assert HomeFormatting.cook_time_label(60) == "1 hr"
    assert HomeFormatting.cook_time_label(90) == "1 hr 30 min"
  end

  test "time_ago/2 words the age like the canvas" do
    assert ago(30) == "Just now"
    assert ago(60) == "1 minute ago"
    assert ago(5 * 60) == "5 minutes ago"
    assert ago(3600) == "1 hour ago"
    assert ago(2 * 3600) == "2 hours ago"
    assert ago(30 * 3600) == "Yesterday"
    assert ago(3 * 86_400) == "3 days ago"
    assert ago(-120) == "Just now"
  end

  test "local_now/2 accepts only an integer offset within UTC-14 to UTC+14" do
    now = ~U[2026-11-12 18:00:00Z]

    assert HomeFormatting.local_now(-300, now) == ~U[2026-11-12 13:00:00Z]
    assert HomeFormatting.local_now(840, now) == ~U[2026-11-13 08:00:00Z]
    assert HomeFormatting.local_now(841, now) == nil
    assert HomeFormatting.local_now("-300", now) == nil
    assert HomeFormatting.local_now(nil, now) == nil
  end
end
