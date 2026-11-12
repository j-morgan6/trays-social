defmodule TraysSocialWeb.HomeFormatting do
  @moduledoc """
  Pure formatting for the web Home page (W242). The greeting kicker
  ("Thursday evening"), the question, the "New" badge rule and the
  cook-time label mirror the iOS `HomeFormatting.swift` from W241.

  `time_ago/2` follows the canvas wording ("2 hours ago" / "Yesterday" /
  "2 days ago"). iOS Home still uses the compact `Date.timeAgo()` ("3h"),
  so the two platforms word that context differently.
  """

  @new_window_seconds 24 * 60 * 60
  @weekdays ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)

  @doc """
  Weekday and part of day for a local datetime: morning 5-11, afternoon
  12-16, evening 17-21, night otherwise.

      iex> greeting_kicker(~N[2026-11-12 18:30:00])
      "Thursday evening"
  """
  @spec greeting_kicker(NaiveDateTime.t() | DateTime.t()) :: String.t()
  def greeting_kicker(local) do
    weekday = Enum.at(@weekdays, Date.day_of_week(local) - 1)
    "#{weekday} #{day_part(local.hour)}"
  end

  @doc "Part of the day for an hour from 0 to 23."
  @spec day_part(0..23) :: String.t()
  def day_part(hour) when hour in 5..11, do: "morning"
  def day_part(hour) when hour in 12..16, do: "afternoon"
  def day_part(hour) when hour in 17..21, do: "evening"
  def day_part(_hour), do: "night"

  @doc "The question under the kicker, personal when there is a username."
  @spec question(String.t() | nil) :: String.t()
  def question(username) when is_binary(username) and username != "",
    do: "What are you cooking, #{username}?"

  def question(_username), do: "What are you cooking?"

  @doc """
  A recipe posted within the last day carries the New badge. Future
  timestamps (clock skew) count as new.
  """
  @spec new?(DateTime.t(), DateTime.t()) :: boolean()
  def new?(inserted_at, now), do: DateTime.diff(now, inserted_at) < @new_window_seconds

  @doc """
  Cook time in the canvas format: "25 min", "1 hr", "1 hr 30 min". Nil when
  there is no positive time.
  """
  @spec cook_time_label(integer() | nil) :: String.t() | nil
  def cook_time_label(minutes) when is_integer(minutes) and minutes > 0 do
    case {div(minutes, 60), rem(minutes, 60)} do
      {0, rest} -> "#{rest} min"
      {hours, 0} -> "#{hours} hr"
      {hours, rest} -> "#{hours} hr #{rest} min"
    end
  end

  def cook_time_label(_minutes), do: nil

  @doc """
  How long ago something was posted, in the canvas wording: "Just now",
  "5 minutes ago", "2 hours ago", "Yesterday", "3 days ago".
  """
  @spec time_ago(DateTime.t(), DateTime.t()) :: String.t()
  def time_ago(datetime, now) do
    now |> DateTime.diff(datetime) |> max(0) |> ago_label()
  end

  defp ago_label(seconds) when seconds < 60, do: "Just now"
  defp ago_label(seconds) when seconds < 3600, do: plural(div(seconds, 60), "minute")
  defp ago_label(seconds) when seconds < 86_400, do: plural(div(seconds, 3600), "hour")
  defp ago_label(seconds) when seconds < 2 * 86_400, do: "Yesterday"
  defp ago_label(seconds), do: plural(div(seconds, 86_400), "day")

  defp plural(1, unit), do: "1 #{unit} ago"
  defp plural(count, unit), do: "#{count} #{unit}s ago"

  @doc """
  The viewer's local time for a UTC offset in minutes, or nil when the
  offset is missing or out of range (-840..840, UTC-14 to UTC+14).
  """
  @spec local_now(term(), DateTime.t()) :: DateTime.t() | nil
  def local_now(offset, now) when is_integer(offset) and offset in -840..840,
    do: DateTime.add(now, offset, :minute)

  def local_now(_offset, _now), do: nil
end
