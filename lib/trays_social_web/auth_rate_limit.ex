defmodule TraysSocialWeb.AuthRateLimit do
  @moduledoc """
  D46: Hammer-backed rate limiting for the auth endpoints.

  Auth-path throttles are universal noise-list exceptions — credential
  stuffing, account enumeration, email bombing, and bulk-account creation
  all flow through the auth endpoints, so we wrap them in a single helper
  that downstream controllers call before any side effect. The limiters:

    * `check_password_login/2` — email + password log-in
    * `check_magic_link_request/2` — sign-in link requests
    * `check_password_reset_request/2` — password reset requests (W254,
      used by `POST /api/v1/auth/reset-password`)
    * `check_registration/1` — new accounts
    * `check_existing_account_notice/1` — the "someone tried to register
      with your email" notice (D123), keyed by the account's email
    * `check_email_change/1` — settings email-change attempts (D123),
      keyed by the signed-in user, so the form can test at most 5
      addresses per user per hour

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

  # Password reset request (W254): 1 per email per 60 seconds (prevent
  # victim email-bombing); 5 per IP per hour (prevent attacker IP rotation).
  # Separate buckets from the magic link, so one cannot starve the other.
  @reset_email_window 60_000
  @reset_email_max 1
  @reset_ip_window 3_600_000
  @reset_ip_max 5

  # Registration: 5 per IP per hour. No email keying — the email is the
  # attacker-chosen identifier.
  @register_ip_window 3_600_000
  @register_ip_max 5

  # Existing-account notice (D123): 1 per email per hour, so a scripted
  # attacker cannot mail-bomb an account owner through registration.
  @existing_account_notice_window 3_600_000
  @existing_account_notice_max 1

  # Email change (D123): 5 attempts per signed-in user per hour, counted
  # on every submission, valid or not.
  @email_change_user_window 3_600_000
  @email_change_user_max 5

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

  @spec check_password_reset_request(Plug.Conn.t(), String.t() | nil) :: :ok | :rate_limited
  def check_password_reset_request(conn, email) do
    with_disable_flag(fn ->
      ip = ip_key(conn)
      email_key = "password_reset:email:#{normalize_email(email)}"
      ip_key = "password_reset:ip:#{ip}"

      with {:allow, _} <-
             Hammer.check_rate(email_key, @reset_email_window, @reset_email_max),
           {:allow, _} <-
             Hammer.check_rate(ip_key, @reset_ip_window, @reset_ip_max) do
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

  @doc """
  D123: allows one existing-account notice per email per hour. Unlike the
  other checks this is keyed only by the account's email, because the
  notice goes to that address whoever triggers it. The registration
  response never depends on the result.
  """
  @spec check_existing_account_notice(String.t() | nil) :: :ok | :rate_limited
  def check_existing_account_notice(email) do
    with_disable_flag(fn ->
      key = "existing_account_notice:email:#{normalize_email(email)}"

      case Hammer.check_rate(key, @existing_account_notice_window, @existing_account_notice_max) do
        {:allow, _} -> :ok
        {:deny, _} -> :rate_limited
      end
    end)
  end

  @doc """
  D123: allows 5 email-change attempts per user per hour, from the settings
  controller and the settings LiveView alike (one shared bucket). A taken
  address shows the neutral message there too, so without a limit a
  signed-in account could test addresses for accounts at will.
  """
  @spec check_email_change(integer()) :: :ok | :rate_limited
  def check_email_change(user_id) when is_integer(user_id) do
    with_disable_flag(fn ->
      key = "email_change:user:#{user_id}"

      case Hammer.check_rate(key, @email_change_user_window, @email_change_user_max) do
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

  @doc """
  The rate-limit identity for the client address. IPv6 clients are keyed by
  their /64: one subscriber usually holds a whole /64, so per-address keys
  would hand them a fresh bucket per request (W254). Also used by
  `TraysSocialWeb.API.RateLimitPlug` (D123).
  """
  @spec ip_key(Plug.Conn.t()) :: String.t()
  def ip_key(%Plug.Conn{remote_ip: {a, b, c, d, _, _, _, _}}) do
    {a, b, c, d, 0, 0, 0, 0} |> :inet.ntoa() |> to_string() |> Kernel.<>("/64")
  end

  def ip_key(%Plug.Conn{remote_ip: ip}) do
    ip |> :inet.ntoa() |> to_string()
  end

  defp normalize_email(nil), do: "_blank_"
  defp normalize_email(email) when is_binary(email), do: String.downcase(email)
  defp normalize_email(_), do: "_blank_"
end
