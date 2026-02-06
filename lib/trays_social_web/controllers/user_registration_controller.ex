defmodule TraysSocialWeb.UserRegistrationController do
  use TraysSocialWeb, :controller

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.User

  def new(conn, _params) do
    changeset = User.registration_changeset(%User{}, %{}, validate_unique: false)
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(
          :info,
          "Account created successfully! Please log in."
        )
        |> redirect(to: ~p"/users/log-in")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end
end
