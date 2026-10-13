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
        conn
        |> send_confirmation(user)
        |> redirect(to: ~p"/")

      :rate_limited ->
        conn
        |> put_flash(:error, "Please wait before requesting another confirmation email.")
        |> redirect(to: ~p"/")
    end
  end

  # D115: the delivery result used to be ignored, so a mailer rejection
  # (Resend error, unverified sender, network) showed the same success
  # flash as a real send and the user was left waiting for nothing.
  # UserNotifier already logs and reports the failure to ErrorTracker;
  # this only tells the user. Logged-out callers keep the generic
  # message so the endpoint reveals nothing about any account.
  defp send_confirmation(conn, %{confirmed_at: nil} = user) do
    case Accounts.deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}")) do
      {:ok, _email} ->
        put_flash(conn, :info, "A new confirmation link has been sent. Check your inbox.")

      {:error, _reason} ->
        put_flash(
          conn,
          :error,
          "We couldn't send the confirmation email right now. Please try again in a few minutes."
        )
    end
  end

  defp send_confirmation(conn, %{confirmed_at: %DateTime{}}) do
    put_flash(conn, :info, "Your email is already confirmed.")
  end

  defp send_confirmation(conn, nil) do
    put_flash(conn, :info, "If your email needs confirmation, a new link has been sent.")
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
