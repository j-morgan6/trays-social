defmodule TraysSocialWeb.UserRegistrationController do
  use TraysSocialWeb, :controller

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.User
  alias TraysSocialWeb.UserAuth

  def new(conn, _params) do
    changeset = User.registration_changeset(%User{}, %{}, validate_unique: false)
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        Accounts.deliver_user_confirmation_instructions(
          user,
          &url(~p"/users/confirm/#{&1}")
        )

        conn
        |> put_flash(:info, "Welcome to Trays! Please check your email to confirm your account.")
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end
end
