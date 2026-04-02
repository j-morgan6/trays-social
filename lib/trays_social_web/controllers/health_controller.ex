defmodule TraysSocialWeb.HealthController do
  use TraysSocialWeb, :controller

  def check(conn, _params) do
    case Ecto.Adapters.SQL.query(TraysSocial.Repo, "SELECT 1") do
      {:ok, _} ->
        json(conn, %{status: "ok", database: "connected"})

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error", database: inspect(reason)})
    end
  end
end
