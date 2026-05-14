defmodule TraysSocialWeb.API.V1.DeviceController do
  use TraysSocialWeb, :controller

  alias TraysSocial.Notifications

  def create(conn, %{"token" => token} = params) do
    user = conn.assigns.current_user
    platform = Map.get(params, "platform", "ios")

    case Notifications.register_device(user.id, token, platform) do
      {:ok, _} ->
        conn
        |> put_status(:created)
        |> json(%{data: %{message: "device registered"}})

      {:error, :token_owned_by_other_user} ->
        # IDOR-safe: respond as if the token simply could not be registered
        # rather than confirming "this token belongs to someone else." 404
        # matches the delete branch so an attacker can't tell which tokens
        # already exist server-side.
        conn
        |> put_status(:not_found)
        |> json(%{errors: [%{message: "device not found"}]})

      {:error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: [%{message: "failed to register device"}]})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: [%{field: "token", message: "is required"}]})
  end

  def delete(conn, %{"token" => token}) do
    user = conn.assigns.current_user

    case Notifications.unregister_device(user.id, token) do
      :ok ->
        json(conn, %{data: %{message: "device unregistered"}})

      {:error, :not_found} ->
        # Missing row and cross-user row return the same 404 — the
        # endpoint must not act as an IDOR oracle (D43).
        conn
        |> put_status(:not_found)
        |> json(%{errors: [%{message: "device not found"}]})
    end
  end
end
