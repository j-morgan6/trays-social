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
    Notifications.unregister_device(token)
    json(conn, %{data: %{message: "device unregistered"}})
  end
end
