defmodule TraysSocialWeb.API.RateLimitPlug do
  @moduledoc """
  Rate limiting plug for API endpoints using Hammer.

  Limits requests by signed-in user, else by client IP address (IPv6 by
  its /64, via `TraysSocialWeb.AuthRateLimit.ip_key/1`). Configure limits per action
  by passing options when plugging:

      plug TraysSocialWeb.API.RateLimitPlug, max_requests: 10, interval_ms: 60_000
  """

  import Plug.Conn

  def init(opts) do
    %{
      max_requests: Keyword.get(opts, :max_requests, 10),
      interval_ms: Keyword.get(opts, :interval_ms, 60_000)
    }
  end

  def call(conn, %{max_requests: max_requests, interval_ms: interval_ms}) do
    if Application.get_env(:trays_social, :disable_rate_limiting, false) do
      conn
    else
      do_rate_limit(conn, max_requests, interval_ms)
    end
  end

  defp do_rate_limit(conn, max_requests, interval_ms) do
    identity =
      case conn.assigns do
        %{current_user: %{id: id}} when not is_nil(id) -> "user:#{id}"
        # D123: IPv6 by /64, as AuthRateLimit keys it, so rotating
        # addresses inside one /64 does not buy a fresh bucket.
        _ -> "ip:#{TraysSocialWeb.AuthRateLimit.ip_key(conn)}"
      end

    bucket_key = "api_rate_limit:#{conn.request_path}:#{identity}"

    case Hammer.check_rate(bucket_key, interval_ms, max_requests) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        retry_after = div(interval_ms, 1000)

        conn
        |> put_resp_header("retry-after", to_string(retry_after))
        |> put_status(:too_many_requests)
        |> Phoenix.Controller.json(%{errors: [%{message: "too many requests"}]})
        |> halt()
    end
  end
end
