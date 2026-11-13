defmodule TraysSocialWeb.API.V1.FeedbackController do
  @moduledoc """
  Accepts in-app bug reports and feedback from signed-in iOS users
  (W123, extended in W261).

  ## Endpoint

      POST /api/v1/feedback

  ## Body

      {
        "kind":         "bug" | "feedback" (optional, default "feedback"),
        "subject":      "Optional subject line (up to 200 chars)",
        "body":         "Required free-text feedback (1 to 5000 chars)",
        "app_version":  "1.0.0",
        "app_build":    "372",
        "os_version":   "17.5",
        "device_model": "iPhone15,3",
        "screen":       "Settings"
      }

  Every key but `body` is optional, so a body from a shipped build (no
  `kind`, `app_build` or `screen`) is stored as before. The `201` response
  is always `{"data": {"id": ..., "status": ...}}`; shipped builds decode
  it as an empty response, so it never gains keys.

  ## Set by the server, never by the client

    * `platform` is always `"ios"` here (the web form will set `"web"`); a
      `platform` in the body is ignored so the source cannot be spoofed.
    * `user_agent` comes from the request's `user-agent` header, cut to
      512 codepoints (dropped if it is not valid UTF-8); a `user_agent` in
      the body is ignored.
    * The owner comes from the bearer token's user (D44/D52).

  No IP address is stored.

  ## Auth, scope and rate limiting

  Authentication is required (`:api_auth`), so feedback is attributable
  and the developer can follow up. Email confirmation is not: the route
  sits in the read scope like `/devices`, because an unconfirmed user is
  the one most likely to need to report a mailer bug.

  Each user may submit 5 times per hour, counted by
  `TraysSocialWeb.FeedbackRateLimit` in one bucket shared with the web
  form, and each client address 20 times per hour across all accounts, so
  throwaway unconfirmed accounts cannot flood the developer. The checks run
  before validation, so an attempt that returns `422` still counts. Over the limit the response is `429` with a `retry-after`
  header and `{"errors": [{"message": "too many requests"}]}`, the same
  shape as `TraysSocialWeb.API.RateLimitPlug`.

  ## Pitfalls (per W123 spec)

    * Body whitespace is trimmed before length validation so a body
      of `"   "` is rejected as empty.
    * The full body is never logged at info level, only metadata
      (id, user_id, kind, platform, subject length, body length, app/os).
  """

  use TraysSocialWeb, :controller

  alias TraysSocial.Feedback
  alias TraysSocialWeb.AuthRateLimit
  alias TraysSocialWeb.FeedbackClientContext
  alias TraysSocialWeb.FeedbackRateLimit

  require Logger

  def create(conn, params) do
    with :ok <- FeedbackRateLimit.check_submission(conn.assigns.current_user.id),
         :ok <- conn |> AuthRateLimit.ip_key() |> FeedbackRateLimit.check_address() do
      do_create(conn, params)
    else
      :rate_limited ->
        conn
        |> put_resp_header("retry-after", to_string(FeedbackRateLimit.retry_after_seconds()))
        |> put_status(:too_many_requests)
        |> json(%{errors: [%{message: "too many requests"}]})
    end
  end

  defp do_create(conn, %{"body" => body} = params) when is_binary(body) do
    attrs = feedback_attrs(conn, body, params)

    case Feedback.submit(conn.assigns.current_user, attrs) do
      {:ok, record} ->
        log_submission(record)

        conn
        |> put_status(:created)
        |> json(%{data: %{id: record.id, status: record.status}})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset_errors(changeset)})
    end
  end

  defp do_create(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: [%{field: "body", message: "is required"}]})
  end

  # The owner comes from current_user via Feedback.submit/2, never from
  # the body (D44/D52). platform and user_agent are set here, never read
  # from params (W261).
  defp feedback_attrs(conn, body, params) do
    %{
      kind: params["kind"],
      platform: "ios",
      subject: params["subject"],
      body: body,
      app_version: params["app_version"],
      app_build: params["app_build"],
      os_version: params["os_version"],
      device_model: params["device_model"],
      screen: params["screen"],
      user_agent: request_user_agent(conn)
    }
  end

  # Headers are raw bytes: invalid UTF-8 is dropped rather than stored, and
  # the cut counts codepoints because the varchar(512) column does. The web
  # form applies the same rule (FeedbackClientContext, W262).
  defp request_user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [ua | _] -> FeedbackClientContext.user_agent(ua)
      [] -> nil
    end
  end

  defp log_submission(record) do
    Logger.info(
      "feedback submitted: id=#{record.id} user_id=#{record.user_id} " <>
        "kind=#{record.kind} platform=#{record.platform} " <>
        "subject_len=#{String.length(record.subject || "")} " <>
        "body_len=#{String.length(record.body)} " <>
        "app=#{record.app_version} os=#{record.os_version}"
    )
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
