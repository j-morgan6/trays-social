defmodule TraysSocialWeb.UserSessionController do
  use TraysSocialWeb, :controller

  alias TraysSocial.Accounts
  alias TraysSocialWeb.AuthRateLimit
  alias TraysSocialWeb.UserAuth

  # D46: invalid-credential and rate-limit denials share the same flash so
  # an attacker cannot distinguish "wrong password" from "throttled" (would
  # otherwise be an oracle for whether the email belongs to a real user
  # currently under attack).
  @generic_login_error "Invalid email or password"

  def new(conn, _params) do
    email = get_in(conn.assigns, [:current_scope, Access.key(:user), Access.key(:email)])
    form = Phoenix.Component.to_form(%{"email" => email}, as: "user")

    render(conn, :new, form: form)
  end

  # magic link login
  def create(conn, %{"user" => %{"token" => token} = user_params} = params) do
    info =
      case params do
        %{"_action" => "confirmed"} -> "User confirmed successfully."
        _ -> "Welcome back!"
      end

    case Accounts.login_user_by_magic_link(token) do
      {:ok, {user, _expired_tokens}} ->
        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> render(:new, form: Phoenix.Component.to_form(%{}, as: "user"))
    end
  end

  # email + password login
  def create(conn, %{"user" => %{"email" => email, "password" => password} = user_params}) do
    case AuthRateLimit.check_password_login(conn, email) do
      :ok ->
        if user = Accounts.get_user_by_email_and_password(email, password) do
          conn
          |> put_flash(:info, "Welcome back!")
          |> UserAuth.log_in_user(user, user_params)
        else
          form = Phoenix.Component.to_form(user_params, as: "user")

          conn
          |> put_flash(:error, @generic_login_error)
          |> render(:new, form: form)
        end

      :rate_limited ->
        form = Phoenix.Component.to_form(user_params, as: "user")

        conn
        |> put_flash(:error, @generic_login_error)
        |> render(:new, form: form)
    end
  end

  # magic link request
  def create(conn, %{"user" => %{"email" => email}}) do
    # Always claim success regardless of outcome — D46 keeps the existing
    # enumeration defense intact. Rate-limited and unknown-email both
    # return the same neutral flash.
    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    case AuthRateLimit.check_magic_link_request(conn, email) do
      :ok ->
        if user = Accounts.get_user_by_email(email) do
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )
        end

      :rate_limited ->
        :noop
    end

    conn
    |> put_flash(:info, info)
    |> redirect(to: ~p"/users/log-in")
  end

  def confirm(conn, %{"token" => token}) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = Phoenix.Component.to_form(%{"token" => token}, as: "user")

      conn
      |> assign(:user, user)
      |> assign(:form, form)
      |> render(:confirm)
    else
      conn
      |> put_flash(:error, "Magic link is invalid or it has expired.")
      |> redirect(to: ~p"/users/log-in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
