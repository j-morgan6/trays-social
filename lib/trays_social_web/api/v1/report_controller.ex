defmodule TraysSocialWeb.API.V1.ReportController do
  use TraysSocialWeb, :controller

  alias TraysSocial.Reports

  action_fallback TraysSocialWeb.API.V1.FallbackController

  def create(conn, params) do
    current_user = conn.assigns.current_user

    attrs = %{
      reporter_id: current_user.id,
      target_type: params["target_type"],
      target_id: params["target_id"],
      reason: params["reason"],
      details: params["details"]
    }

    case Reports.create_report(attrs) do
      {:ok, _report} ->
        json(conn, %{data: %{message: "Report submitted successfully"}})

      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
              opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
            end)
          end)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: errors})
    end
  end
end
