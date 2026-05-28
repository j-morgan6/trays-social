defmodule TraysSocialWeb.API.V1.FeedbackController do
  @moduledoc """
  Accepts in-app feedback submissions from authenticated iOS users.

  ## Endpoint

      POST /api/v1/feedback

  ## Body

      {
        "subject":      "Optional subject line",
        "body":         "Required free-text feedback (1–5000 chars)",
        "app_version":  "1.0.0",
        "os_version":   "17.5",
        "device_model": "iPhone15,3"
      }

  ## Auth + rate limiting

  Authentication required — feedback must be attributable so the
  operator can follow up. Rate-limited via `api_rate_limit_write`
  (60/min/user) which is plenty for human-typed feedback.

  ## Pitfalls (per W123 spec)

    * Body whitespace is trimmed before length validation so a body
      of `"   "` is rejected as empty.
    * The full body is never logged at info level — only metadata
      (id, user_id, subject length, body length, app/os/device).
  """

  use TraysSocialWeb, :controller

  require Logger

  alias TraysSocial.Feedback

  def create(conn, %{"body" => body} = params) when is_binary(body) do
    user = conn.assigns.current_user

    attrs = %{
      user_id: user.id,
      subject: params["subject"],
      body: body,
      app_version: params["app_version"],
      os_version: params["os_version"],
      device_model: params["device_model"]
    }

    case Feedback.submit(attrs) do
      {:ok, record} ->
        Logger.info(
          "feedback submitted: id=#{record.id} user_id=#{record.user_id} " <>
            "subject_len=#{String.length(record.subject || "")} " <>
            "body_len=#{String.length(record.body)} " <>
            "app=#{record.app_version} os=#{record.os_version}"
        )

        conn
        |> put_status(:created)
        |> json(%{data: %{id: record.id, status: record.status}})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset_errors(changeset)})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: [%{field: "body", message: "is required"}]})
  end

  defp changeset_errors(changeset) do
    Enum.flat_map(changeset.errors, fn {field, {msg, opts}} ->
      [%{field: to_string(field), message: render_msg(msg, opts)}]
    end)
  end

  defp render_msg(msg, opts) do
    Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
      opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
  end
end
