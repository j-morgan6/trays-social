defmodule TraysSocialWeb.Plugs.TrustedRemoteIp do
  @moduledoc """
  D45: rewrite `conn.remote_ip` from X-Forwarded-For only when the TCP peer
  is in the trusted-proxy list.

  Plain `RemoteIp` is peer-blind — it rewrites the IP whenever the configured
  header is present, regardless of who sent the request. That is fine when
  the endpoint is provably behind a managed proxy (Fly, Cloudflare), but
  becomes a spoofing oracle if any request from outside the proxy mesh ever
  reaches the app (misconfigured DNS, internal LAN traffic, a stray test
  harness). This plug gates the rewrite on the peer being a known proxy,
  matching the behavior the security review asked for in the AC.

  Trusted proxies for this deployment:
    * 127.0.0.0/8  — loopback (dev/test)
    * fdaa::/16    — Fly.io internal IPv6 mesh (their edge proxies)
  """

  @behaviour Plug

  @trusted_cidrs ~w[127.0.0.0/8 fdaa::/16]
  @inner_opts RemoteIp.init(headers: ~w[x-forwarded-for], proxies: @trusted_cidrs)

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    if trusted_peer?(conn.remote_ip) do
      RemoteIp.call(conn, @inner_opts)
    else
      conn
    end
  end

  # 127.0.0.0/8
  defp trusted_peer?({127, _, _, _}), do: true
  # fdaa::/16 — first 16 bits of the IPv6 address equal 0xFDAA. Fly's
  # internal mesh covers their edge proxies, which is what we need to trust.
  defp trusted_peer?({0xFDAA, _, _, _, _, _, _, _}), do: true
  defp trusted_peer?(_), do: false
end
