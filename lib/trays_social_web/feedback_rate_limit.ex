defmodule TraysSocialWeb.FeedbackRateLimit do
  @moduledoc """
  W261: the per-user limit on bug reports and feedback.

  One Hammer bucket per signed-in user, `feedback:user:<id>`, allows 5
  submissions per hour. The API (`POST /api/v1/feedback`) checks it today
  and the web feedback form will check the same bucket, so the limit holds
  across web and iOS combined rather than per client.

  Accounts are cheap to create and confirmation is not required, so a
  second bucket, `feedback:ip:<address>` (IPv6 by its /64, via
  `TraysSocialWeb.AuthRateLimit.ip_key/1`), allows 20 submissions per hour
  from one network across every account. One actor cycling throwaway
  accounts from one place therefore stays under the developer email cap
  (30 per hour, `TraysSocial.Feedback.Notifier`).

  The checks count every attempt, including one that later fails
  validation, so they run once at the top of the caller before any insert.

  Honors `Application.get_env(:trays_social, :disable_rate_limiting,
  false)` like `TraysSocialWeb.AuthRateLimit`, so the test suite can opt
  out by default.
  """

  @window_ms 3_600_000
  @max_submissions 5
  @max_address_submissions 20

  @doc """
  Counts one submission attempt for `user_id`. Returns `:ok` while the user
  is within 5 per hour, else `:rate_limited`.
  """
  @spec check_submission(integer()) :: :ok | :rate_limited
  def check_submission(user_id) when is_integer(user_id) do
    if Application.get_env(:trays_social, :disable_rate_limiting, false) do
      :ok
    else
      case Hammer.check_rate("feedback:user:#{user_id}", @window_ms, @max_submissions) do
        {:allow, _count} -> :ok
        {:deny, _limit} -> :rate_limited
      end
    end
  end

  @doc """
  Counts one submission attempt from the client address `ip_key` (from
  `TraysSocialWeb.AuthRateLimit.ip_key/1`), across all accounts. Returns
  `:ok` while the address is within 20 per hour, else `:rate_limited`.
  """
  @spec check_address(String.t()) :: :ok | :rate_limited
  def check_address(ip_key) when is_binary(ip_key) do
    if Application.get_env(:trays_social, :disable_rate_limiting, false) do
      :ok
    else
      case Hammer.check_rate("feedback:ip:#{ip_key}", @window_ms, @max_address_submissions) do
        {:allow, _count} -> :ok
        {:deny, _limit} -> :rate_limited
      end
    end
  end

  @doc "The window length in seconds, for a `retry-after` header."
  @spec retry_after_seconds() :: pos_integer()
  def retry_after_seconds, do: div(@window_ms, 1000)
end
