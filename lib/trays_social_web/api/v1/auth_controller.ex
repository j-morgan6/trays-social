defmodule TraysSocialWeb.API.V1.AuthController do
  use TraysSocialWeb, :controller

  action_fallback TraysSocialWeb.API.V1.FallbackController

  alias TraysSocial.Accounts

  def register(conn, %{"email" => email, "username" => username, "password" => password}) do
    case Accounts.register_user(%{email: email, username: username, password: password}) do
      {:ok, user} ->
        token = Accounts.generate_user_api_token(user)
        encoded_token = Base.encode64(token)

        conn
        |> put_status(:created)
        |> json(%{data: %{token: encoded_token, user: user_json(user)}})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def register(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: [%{message: "email, username, and password are required"}]})
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        {:error, :unauthorized}

      user ->
        token = Accounts.generate_user_api_token(user)
        encoded_token = Base.encode64(token)

        json(conn, %{data: %{token: encoded_token, user: user_json(user)}})
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: [%{message: "email and password are required"}]})
  end

  def logout(conn, _params) do
    # The raw token is already decoded by AuthPlug, but we need it to delete
    # Extract it from the header again
    ["Bearer " <> encoded_token] = get_req_header(conn, "authorization")
    token = Base.decode64!(encoded_token)
    Accounts.delete_user_api_token(token)

    json(conn, %{data: %{message: "logged out"}})
  end

  def me(conn, _params) do
    user = conn.assigns.current_user
    needs_username = is_nil(user.username) or user.username == ""

    json(conn, %{data: Map.merge(user_json(user), %{needs_username: needs_username})})
  end

  defp user_json(user) do
    %{
      id: user.id,
      email: user.email,
      username: user.username,
      bio: user.bio,
      profile_photo_url: user.profile_photo_url,
      inserted_at: user.inserted_at
    }
  end
end
