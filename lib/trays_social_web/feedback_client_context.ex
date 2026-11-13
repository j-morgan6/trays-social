defmodule TraysSocialWeb.FeedbackClientContext do
  @moduledoc """
  W262: the request context the server attaches to a bug report or
  feedback submission, shared by the API (`POST /api/v1/feedback`) and the
  web form (`TraysSocialWeb.FeedbackLive.Index`).

    * `user_agent/1` - the browser or app user agent, valid UTF-8 only,
      cut to the column's 512 codepoints.
    * `from_path/1` - the `?from=` path the web form stores as `screen`.
      Only a relative path is kept. It is stored for triage and never used
      to redirect or rendered as a link.
    * `live_session/1` - the router `live_session` session callback that
      hands the web form the client's rate-limit address key.

  No IP address is stored with a submission. The address key from
  `live_session/1` lives only in the signed LiveView session on the user's
  own page and in the form's process, where it selects the shared per-address
  bucket in `TraysSocialWeb.FeedbackRateLimit`.
  """

  alias TraysSocialWeb.AuthRateLimit

  @user_agent_max 512
  @from_max 120

  @doc """
  The user agent to store: `nil` unless it is a non-empty, valid UTF-8
  string, else its first 512 codepoints (the varchar column counts
  codepoints).
  """
  @spec user_agent(term()) :: String.t() | nil
  def user_agent(ua) when is_binary(ua) and ua != "" do
    if String.valid?(ua) do
      ua |> String.codepoints() |> Enum.take(@user_agent_max) |> Enum.join()
    end
  end

  def user_agent(_ua), do: nil

  @doc """
  The `?from=` value to store as `screen`, or `nil`.

  Kept only when it is a relative path: valid UTF-8 starting with a single
  `/` (not `//` or `/\\`, which browsers read as another host), with no
  control characters and at most 120 codepoints. Anything else, including a
  list or map from `from[]=`, is dropped.
  """
  @spec from_path(term()) :: String.t() | nil
  def from_path("/" <> rest = from) when is_binary(rest) do
    if relative_path?(from), do: from
  end

  def from_path(_from), do: nil

  defp relative_path?(from) do
    String.valid?(from) and
      not String.starts_with?(from, ["//", "/\\"]) and
      not String.match?(from, ~r/[\x00-\x1F\x7F]/) and
      length(String.codepoints(from)) <= @from_max
  end

  @doc """
  Router `live_session` session callback. It runs on the HTTP request,
  after `TraysSocialWeb.Plugs.TrustedRemoteIp` has set `conn.remote_ip`
  from the proxy chain, so the key is the real client's; the LiveView
  socket connects before the endpoint plugs and could not get it itself.
  The value is signed into the LiveView session, so the client cannot
  change it.
  """
  @spec live_session(Plug.Conn.t()) :: %{String.t() => String.t()}
  def live_session(%Plug.Conn{} = conn) do
    %{"feedback_ip_key" => AuthRateLimit.ip_key(conn)}
  end
end
