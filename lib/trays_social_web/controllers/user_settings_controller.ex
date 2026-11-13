defmodule TraysSocialWeb.UserSettingsController do
  use TraysSocialWeb, :controller

  import TraysSocialWeb.UserAuth, only: [require_sudo_mode: 2]

  alias TraysSocial.Accounts
  alias TraysSocialWeb.AuthRateLimit
  alias TraysSocialWeb.UserAuth

  @email_change_failed "We couldn't send the confirmation link right now. Please try again in a few minutes."
  @email_change_rate_limited "Unable to change your email right now. Please try again later."

  plug :require_sudo_mode
  plug :assign_email_and_password_changesets

  def edit(conn, _params) do
    render(conn, :edit)
  end

  def update(conn, %{"action" => "update_email"} = params) do
    user = conn.assigns.current_scope.user

    # D123: every attempt counts, so the form can test at most 5 addresses
    # per user per hour (the accepted limitation is described in
    # ExistingAccountNotice). Neutral copy, as in D46.
    case AuthRateLimit.check_email_change(user.id) do
      :ok ->
        update_email(conn, user, params)

      :rate_limited ->
        conn
        |> put_flash(:error, @email_change_rate_limited)
        |> redirect(to: ~p"/users/settings")
    end
  end

  def update(conn, %{"action" => "update_password"} = params) do
    %{"user" => user_params} = params
    user = conn.assigns.current_scope.user

    case Accounts.update_user_password(user, user_params) do
      {:ok, {user, _}} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:user_return_to, ~p"/users/settings")
        |> UserAuth.log_in_user(user)

      {:error, changeset} ->
        render(conn, :edit, password_changeset: changeset)
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    case Accounts.update_user_email(conn.assigns.current_scope.user, token) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: ~p"/users/settings")

      {:error, _} ->
        conn
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: ~p"/users/settings")
    end
  end

  defp update_email(conn, user, %{"user" => user_params}) do
    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        delivery =
          changeset
          |> Ecto.Changeset.apply_action!(:insert)
          |> Accounts.deliver_user_update_email_instructions(
            user.email,
            &url(~p"/users/settings/confirm-email/#{&1}")
          )

        # D117: never claim the link was sent when the mailer failed.
        case delivery do
          {:ok, _email} ->
            put_flash(
              conn,
              :info,
              "A link to confirm your email change has been sent to the new address."
            )

          {:error, _reason} ->
            put_flash(conn, :error, @email_change_failed)
        end
        |> redirect(to: ~p"/users/settings")

      changeset ->
        render(conn, :edit, email_changeset: %{changeset | action: :insert})
    end
  end

  defp assign_email_and_password_changesets(conn, _opts) do
    user = conn.assigns.current_scope.user

    conn
    |> assign(:email_changeset, Accounts.change_user_email(user))
    |> assign(:password_changeset, Accounts.change_user_password(user))
  end
end
