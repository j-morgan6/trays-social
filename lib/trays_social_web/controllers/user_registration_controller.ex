defmodule TraysSocialWeb.UserRegistrationController do
  use TraysSocialWeb, :controller

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.User
  alias TraysSocialWeb.AuthRateLimit
  alias TraysSocialWeb.ExistingAccountNotice
  alias TraysSocialWeb.UserAuth

  # W252: the sign-in pages show info and error flashes in place (the amber
  # callout above the button, the mint "check your email" box), so the root
  # layout leaves them out of its toast group on these pages.
  plug :inline_flash

  def new(conn, _params) do
    changeset = User.registration_changeset(%User{}, %{}, validate_unique: false)
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case AuthRateLimit.check_registration(conn) do
      :ok ->
        do_create(conn, user_params)

      :rate_limited ->
        # D46: neutral flash that doesn't reveal the rate limit exists —
        # an attacker probing for a throttle would otherwise know to
        # rotate IPs. The :new template just shows the form again.
        changeset = User.registration_changeset(%User{}, user_params, validate_unique: false)

        conn
        |> put_flash(:error, "Unable to create your account right now. Please try again later.")
        |> render(:new, changeset: changeset)
    end
  end

  defp do_create(conn, user_params) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # D117: the account is created and the user logged in either way; a
        # failed send only changes the message. deliver/4 already logs and
        # reports the failure, so the reason is never shown to the user.
        flash =
          case Accounts.deliver_user_confirmation_instructions(
                 user,
                 &url(~p"/users/confirm/#{&1}")
               ) do
            {:ok, _email} ->
              {:info, "Welcome to Trays! Please check your email to confirm your account."}

            {:error, _reason} ->
              {:error,
               "Welcome to Trays! We couldn't send your confirmation email right now. " <>
                 "Use \"Resend verification email\" in a few minutes."}
          end

        {kind, message} = flash

        conn
        |> put_flash(kind, message)
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        # D123: a taken email shows the neutral message on the email field
        # (User.validate_email/2) and the owner gets a rate-limited notice
        # instead; the page re-renders exactly as for any other error.
        :ok = ExistingAccountNotice.maybe_send(changeset)
        render(conn, :new, changeset: changeset)
    end
  end

  defp inline_flash(conn, _opts), do: assign(conn, :inline_flash, true)
end
