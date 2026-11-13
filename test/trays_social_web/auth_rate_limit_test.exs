defmodule TraysSocialWeb.AuthRateLimitTest do
  @moduledoc """
  D46 regression tests. Rate limiting is disabled globally in
  config/test.exs (so the rest of the suite doesn't fight with throttles);
  these tests flip it back on for their own scope.

  async: false — the disable flag and Hammer's process-global buckets are
  process-wide.
  """
  use TraysSocialWeb.ConnCase, async: false

  alias TraysSocialWeb.AuthRateLimit

  setup do
    Application.put_env(:trays_social, :disable_rate_limiting, false)
    on_exit(fn -> Application.put_env(:trays_social, :disable_rate_limiting, true) end)
    :ok
  end

  # Give each test a fresh remote_ip so Hammer buckets don't carry across
  # tests in the same suite run.
  defp conn_for_ip(ip) when is_binary(ip) do
    [a, b, c, d] = ip |> String.split(".") |> Enum.map(&String.to_integer/1)
    %{build_conn() | remote_ip: {a, b, c, d}}
  end

  defp uniq_ip do
    "10.#{Enum.random(0..255)}.#{Enum.random(0..255)}.#{Enum.random(0..255)}"
  end

  describe "check_password_login/2" do
    test "allows up to 5 attempts per email per 15 minutes" do
      email = "limit-#{System.unique_integer([:positive])}@example.com"
      conn = conn_for_ip(uniq_ip())

      for _ <- 1..5 do
        assert :ok = AuthRateLimit.check_password_login(conn, email)
      end

      assert :rate_limited = AuthRateLimit.check_password_login(conn, email)
    end

    test "allows up to 20 attempts per IP per 15 minutes (across emails)" do
      ip = uniq_ip()
      conn = conn_for_ip(ip)

      # 20 distinct emails, one attempt each — keeps the per-email bucket
      # at 1 while the per-IP bucket fills up.
      for i <- 1..20 do
        email = "ip-load-#{System.unique_integer([:positive])}-#{i}@example.com"
        assert :ok = AuthRateLimit.check_password_login(conn, email)
      end

      blocked_email = "ip-load-#{System.unique_integer([:positive])}-21@example.com"
      assert :rate_limited = AuthRateLimit.check_password_login(conn, blocked_email)
    end

    test "treats email case-insensitively" do
      email = "Case-#{System.unique_integer([:positive])}@Example.COM"
      conn = conn_for_ip(uniq_ip())

      for _ <- 1..5 do
        assert :ok = AuthRateLimit.check_password_login(conn, email)
      end

      assert :rate_limited =
               AuthRateLimit.check_password_login(conn, String.downcase(email))
    end
  end

  describe "check_magic_link_request/2" do
    test "allows 1 per email per 60 seconds" do
      email = "magic-#{System.unique_integer([:positive])}@example.com"
      conn = conn_for_ip(uniq_ip())

      assert :ok = AuthRateLimit.check_magic_link_request(conn, email)
      assert :rate_limited = AuthRateLimit.check_magic_link_request(conn, email)
    end

    test "allows up to 5 per IP per hour (across emails)" do
      ip = uniq_ip()
      conn = conn_for_ip(ip)

      for i <- 1..5 do
        email = "magic-ip-#{System.unique_integer([:positive])}-#{i}@example.com"
        assert :ok = AuthRateLimit.check_magic_link_request(conn, email)
      end

      sixth = "magic-ip-#{System.unique_integer([:positive])}-6@example.com"
      assert :rate_limited = AuthRateLimit.check_magic_link_request(conn, sixth)
    end
  end

  describe "check_password_reset_request/2" do
    test "allows 1 per email per 60 seconds, case-insensitively" do
      email = "reset-#{System.unique_integer([:positive])}@example.com"
      conn = conn_for_ip(uniq_ip())

      assert :ok = AuthRateLimit.check_password_reset_request(conn, email)
      assert :rate_limited = AuthRateLimit.check_password_reset_request(conn, email)

      assert :rate_limited =
               AuthRateLimit.check_password_reset_request(conn, String.upcase(email))
    end

    test "allows up to 5 per IP per hour (across emails)" do
      conn = conn_for_ip(uniq_ip())

      for i <- 1..5 do
        email = "reset-ip-#{System.unique_integer([:positive])}-#{i}@example.com"
        assert :ok = AuthRateLimit.check_password_reset_request(conn, email)
      end

      sixth = "reset-ip-#{System.unique_integer([:positive])}-6@example.com"
      assert :rate_limited = AuthRateLimit.check_password_reset_request(conn, sixth)
    end

    test "keys IPv6 clients by their /64, so rotating the interface id does not help" do
      prefix = {0x2001, 0xDB8, Enum.random(0..0xFFFF), Enum.random(0..0xFFFF)}
      {a, b, c, d} = prefix

      for i <- 1..5 do
        conn = %{build_conn() | remote_ip: {a, b, c, d, 0, 0, 0, i}}
        email = "reset-v6-#{System.unique_integer([:positive])}@example.com"
        assert :ok = AuthRateLimit.check_password_reset_request(conn, email)
      end

      sixth = %{build_conn() | remote_ip: {a, b, c, d, 0xFFFF, 1, 2, 3}}
      email = "reset-v6-#{System.unique_integer([:positive])}@example.com"
      assert :rate_limited = AuthRateLimit.check_password_reset_request(sixth, email)
    end

    test "does not share buckets with the magic-link limiter" do
      email = "reset-magic-#{System.unique_integer([:positive])}@example.com"
      conn = conn_for_ip(uniq_ip())

      assert :ok = AuthRateLimit.check_magic_link_request(conn, email)
      assert :ok = AuthRateLimit.check_password_reset_request(conn, email)
    end
  end

  describe "check_registration/1" do
    test "allows up to 5 registrations per IP per hour" do
      conn = conn_for_ip(uniq_ip())

      for _ <- 1..5 do
        assert :ok = AuthRateLimit.check_registration(conn)
      end

      assert :rate_limited = AuthRateLimit.check_registration(conn)
    end
  end

  # D123
  describe "check_email_change/1" do
    test "allows 5 email-change attempts per user per hour, then limits only that user" do
      user_id = System.unique_integer([:positive])
      other_id = System.unique_integer([:positive])

      for _ <- 1..5, do: assert(AuthRateLimit.check_email_change(user_id) == :ok)
      assert AuthRateLimit.check_email_change(user_id) == :rate_limited
      assert AuthRateLimit.check_email_change(other_id) == :ok
    end
  end

  describe "ip_key/1" do
    test "keys IPv6 by its /64 and IPv4 by the full address" do
      v6 = fn ip -> %{build_conn() | remote_ip: ip} end

      assert AuthRateLimit.ip_key(v6.({0x2001, 0xDB8, 1, 2, 3, 4, 5, 6})) ==
               AuthRateLimit.ip_key(v6.({0x2001, 0xDB8, 1, 2, 9, 9, 9, 9}))

      refute AuthRateLimit.ip_key(v6.({0x2001, 0xDB8, 1, 2, 3, 4, 5, 6})) ==
               AuthRateLimit.ip_key(v6.({0x2001, 0xDB8, 1, 3, 3, 4, 5, 6}))

      assert AuthRateLimit.ip_key(conn_for_ip("10.1.2.3")) == "10.1.2.3"
    end
  end

  describe "disable flag" do
    test "honors :disable_rate_limiting=true" do
      Application.put_env(:trays_social, :disable_rate_limiting, true)
      conn = conn_for_ip(uniq_ip())

      # Far past any limit — but the flag short-circuits everything.
      for _ <- 1..50 do
        assert :ok = AuthRateLimit.check_password_login(conn, "x@example.com")
      end
    end
  end
end
