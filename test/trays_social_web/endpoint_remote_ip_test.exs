defmodule TraysSocialWeb.EndpointRemoteIpTest do
  @moduledoc """
  D45 regression: TrustedRemoteIp must honor X-Forwarded-For only when the
  TCP peer is itself in the trusted-proxy list, and leave conn.remote_ip
  alone for everyone else. Without this peer check, an attacker can spoof
  `conn.remote_ip` by setting the header — collapsing every per-IP
  rate-limit bucket to whatever IP they pick.
  """
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias TraysSocialWeb.Plugs.TrustedRemoteIp

  defp call_with_peer(peer_ip, xff_value) do
    conn = conn(:get, "/")
    conn = %{conn | remote_ip: peer_ip}

    conn
    |> put_req_header("x-forwarded-for", xff_value)
    |> TrustedRemoteIp.call(TrustedRemoteIp.init([]))
  end

  test "rewrites remote_ip when peer is loopback (trusted)" do
    %{remote_ip: ip} = call_with_peer({127, 0, 0, 1}, "203.0.113.42")
    assert ip == {203, 0, 113, 42}
  end

  test "rewrites remote_ip when peer is in Fly internal range (fdaa::/16)" do
    fly_peer = {0xFDAA, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x1}
    %{remote_ip: ip} = call_with_peer(fly_peer, "198.51.100.7")
    assert ip == {198, 51, 100, 7}
  end

  test "ignores X-Forwarded-For when peer is NOT a trusted proxy" do
    untrusted_peer = {198, 51, 100, 99}
    %{remote_ip: ip} = call_with_peer(untrusted_peer, "203.0.113.42")
    # XFF is dropped on the floor; remote_ip stays at the actual peer.
    assert ip == untrusted_peer
  end

  test "ignores X-Forwarded-For claiming to be the trusted proxy itself" do
    # An attacker connecting from a non-trusted peer cannot pretend their
    # XFF makes them trusted — the trust decision is based on conn.remote_ip
    # (TCP peer), which they can't forge.
    untrusted_peer = {203, 0, 113, 99}
    %{remote_ip: ip} = call_with_peer(untrusted_peer, "127.0.0.1, 198.51.100.7")
    assert ip == untrusted_peer
  end

  test "picks the rightmost client when the chain has multiple proxies" do
    # XFF list semantics: client, proxy1, proxy2, ...
    # RemoteIp walks right-to-left, skipping trusted proxies, and stops at
    # the first non-trusted address — that's the real client.
    %{remote_ip: ip} = call_with_peer({127, 0, 0, 1}, "198.51.100.7, 127.0.0.2")
    assert ip == {198, 51, 100, 7}
  end

  test "is a no-op when there is no X-Forwarded-For header" do
    conn = conn(:get, "/")
    conn = %{conn | remote_ip: {127, 0, 0, 1}}
    %{remote_ip: ip} = TrustedRemoteIp.call(conn, TrustedRemoteIp.init([]))
    assert ip == {127, 0, 0, 1}
  end
end
