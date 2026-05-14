defmodule TraysSocialWeb.AuthRateLimit do
  @moduledoc """
  D46: Hammer-backed rate limiting for the auth endpoints.

  Auth-path throttles are universal noise-list exceptions — credential
  stuffing, account enumeration, email bombing, and bulk-account creation
  all flow through the same three endpoints, so we wrap them in a single
  helper that downstream controllers call before any side effect.

  Each function returns `:ok` or `:rate_limited`. The caller is responsible
  for translating `:rate_limited` into a generic flash message — *never*
  one that says "rate limited" — to preserve the enumeration-defense
  behavior already in place for invalid-credential responses.

  Honors `Application.get_env(:trays_social, :disable_rate_limiting,
  false)` so the test suite can opt out by default.
  """

  # Password login: 5 per email per 15 minutes; 20 per IP per 15 minutes.
  @password_email_window 15 * 60_000
  @password_email_max 5
  @password_ip_window 15 * 60_000
  @password_ip_max 20

  # Magic link: 1 per email per 60 seconds (prevent victim email-bombing);
  # 5 per IP per hour (prevent attacker IP rotation).
  @magic_email_window 60_000
  @magic_email_max 1
  @magic_ip_window 3_600_000
  @magic_ip_max 5

  # Registration: 5 per IP per hour. No email keying — the email is the
  # attacker-chosen identifier.
  @register_ip_window 3_600_000
  @register_ip_max 5

  @spec check_password_login(Plug.Conn.t(), String.t() | nil) :: :ok | :rate_limited
  def check_password_login(conn, email) do
    with_disable_flag(fn ->
      ip = ip_key(conn)
      email_key = "password_login:email:#{normalize_email(email)}"
      ip_key = "password_login:ip:#{ip}"

      with {:allow, _} <-
             Hammer.check_rate(email_key, @password_email_window, @password_email_max),
           {:allow, _} <-
             Hammer.check_rate(ip_key, @password_ip_window, @password_ip_max) do
        :ok
      else
        {:deny, _} -> :rate_limited
      end
    end)
  end

  @spec check_magic_link_request(Plug.Conn.t(), String.t() | nil) :: :ok | :rate_limited
  def check_magic_link_request(conn, email) do
    with_disable_flag(fn ->
      ip = ip_key(conn)
      email_key = "magic_link:email:#{normalize_email(email)}"
      ip_key = "magic_link:ip:#{ip}"

      with {:allow, _} <-
             Hammer.check_rate(email_key, @magic_email_window, @magic_email_max),
           {:allow, _} <-
             Hammer.check_rate(ip_key, @magic_ip_window, @magic_ip_max) do
        :ok
      else
        {:deny, _} -> :rate_limited
      end
    end)
  end

  @spec check_registration(Plug.Conn.t()) :: :ok | :rate_limited
  def check_registration(conn) do
    with_disable_flag(fn ->
      ip_key = "registration:ip:#{ip_key(conn)}"

      case Hammer.check_rate(ip_key, @register_ip_window, @register_ip_max) do
        {:allow, _} -> :ok
        {:deny, _} -> :rate_limited
      end
    end)
  end

  defp with_disable_flag(fun) do
    if Application.get_env(:trays_social, :disable_rate_limiting, false) do
      :ok
    else
      fun.()
    end
  end

  defp ip_key(%Plug.Conn{remote_ip: ip}) do
    ip |> :inet.ntoa() |> to_string()
  end

  defp normalize_email(nil), do: "_blank_"
  defp normalize_email(email) when is_binary(email), do: String.downcase(email)
  defp normalize_email(_), do: "_blank_"
end
