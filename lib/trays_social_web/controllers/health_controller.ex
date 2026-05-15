defmodule TraysSocialWeb.HealthController do
  use TraysSocialWeb, :controller

  require Logger

  def check(conn, _params) do
    case Ecto.Adapters.SQL.query(TraysSocial.Repo, "SELECT 1") do
      {:ok, _} ->
        json(conn, %{status: "ok", database: "connected"})

      {:error, reason} ->
        # D58: don't leak driver internals (PostgreSQL version, internal
        # hostnames, query context — anything Postgrex puts in the struct)
        # to an unauthenticated probe. Fixed shape for the wire; full
        # detail goes to the server log for operators.
        Logger.error("Health check failed: database unavailable. reason=#{inspect(reason)}")

        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error", database: "unavailable"})
    end
  end
end
