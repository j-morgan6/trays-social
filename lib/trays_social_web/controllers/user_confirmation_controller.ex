defmodule TraysSocialWeb.UserConfirmationController do
  use TraysSocialWeb, :controller

  alias TraysSocial.Accounts

  @user_rate_limit_ms 60_000
  @ip_rate_limit_ms 3_600_000
  @ip_max_requests 5

  def confirm(conn, %{"token" => token}) do
    case Accounts.confirm_user_by_token(token) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Email confirmed successfully.")
        |> redirect(to: ~p"/")

      :error ->
        conn
        |> put_flash(:error, "Confirmation link is invalid or has expired.")
        |> redirect(to: ~p"/")
    end
  end

  def resend(conn, _params) do
    user = conn.assigns.current_scope && conn.assigns.current_scope.user

    case check_resend_rate_limit(conn, user) do
      :ok ->
        if user && is_nil(user.confirmed_at) do
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )
        end

        conn
        |> put_flash(:info, "If your email needs confirmation, a new link has been sent.")
        |> redirect(to: ~p"/")

      :rate_limited ->
        conn
        |> put_flash(:error, "Please wait before requesting another confirmation email.")
        |> redirect(to: ~p"/")
    end
  end

  defp check_resend_rate_limit(conn, user) do
    if Application.get_env(:trays_social, :disable_rate_limiting, false) do
      :ok
    else
      ip = conn.remote_ip |> :inet.ntoa() |> to_string()
      user_key = if user, do: "confirm_resend:user:#{user.id}", else: "confirm_resend:anon"
      ip_key = "confirm_resend:ip:#{ip}"

      with {:allow, _} <- Hammer.check_rate(user_key, @user_rate_limit_ms, 1),
           {:allow, _} <- Hammer.check_rate(ip_key, @ip_rate_limit_ms, @ip_max_requests) do
        :ok
      else
        {:deny, _} -> :rate_limited
      end
    end
  end
end
