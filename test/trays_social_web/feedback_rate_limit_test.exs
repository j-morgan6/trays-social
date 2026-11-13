defmodule TraysSocialWeb.FeedbackRateLimitTest do
  # Not async: these tests flip the global :disable_rate_limiting flag.
  use ExUnit.Case, async: false

  alias TraysSocialWeb.FeedbackRateLimit

  setup do
    Application.put_env(:trays_social, :disable_rate_limiting, false)
    on_exit(fn -> Application.put_env(:trays_social, :disable_rate_limiting, true) end)
    :ok
  end

  # Hammer buckets are global, so every test uses a user id no other test has.
  defp fresh_user_id, do: System.unique_integer([:positive])

  test "the sixth submission in an hour for one user is rate limited" do
    user_id = fresh_user_id()

    for _ <- 1..5, do: assert(FeedbackRateLimit.check_submission(user_id) == :ok)

    assert FeedbackRateLimit.check_submission(user_id) == :rate_limited
  end

  test "each user has their own bucket" do
    limited = fresh_user_id()
    other = fresh_user_id()

    for _ <- 1..6, do: FeedbackRateLimit.check_submission(limited)

    assert FeedbackRateLimit.check_submission(limited) == :rate_limited
    assert FeedbackRateLimit.check_submission(other) == :ok
  end

  test "the 21st submission in an hour from one address is rate limited" do
    ip = "198.51.100.#{System.unique_integer([:positive])}"

    for _ <- 1..20, do: assert(FeedbackRateLimit.check_address(ip) == :ok)

    assert FeedbackRateLimit.check_address(ip) == :rate_limited
    assert FeedbackRateLimit.check_address(ip <> "-other") == :ok
  end

  test "the limit honors :disable_rate_limiting" do
    Application.put_env(:trays_social, :disable_rate_limiting, true)
    user_id = fresh_user_id()

    for _ <- 1..20, do: assert(FeedbackRateLimit.check_submission(user_id) == :ok)
    for _ <- 1..30, do: assert(FeedbackRateLimit.check_address("disabled-flag-ip") == :ok)
  end

  test "retry_after_seconds is the one-hour window" do
    assert FeedbackRateLimit.retry_after_seconds() == 3600
  end
end
