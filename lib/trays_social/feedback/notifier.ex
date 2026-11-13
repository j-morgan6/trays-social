defmodule TraysSocial.Feedback.Notifier do
  @moduledoc """
  Emails the developer about a new bug report or feedback submission (W260).

  One text-only email goes to each address in
  `config :trays_social, :admin_emails`. It carries the kind, platform, app
  version and build, OS, device, screen, a 500-character excerpt of the
  body and a link to `/admin/feedback/:id`, so most reports can be acted
  on without opening the admin page.

  Best effort, by design:

    * `TraysSocial.Feedback.submit/2` stores the row first and calls this
      from a supervised task, so nothing here can fail or delay a
      submission.
    * At most 30 notifications are sent per hour overall (Hammer). Rows
      beyond the cap are only stored, and the cap is logged once per window.
      The cap honours `:disable_rate_limiting`, like the other limiters.
    * A send failure is logged and reported to ErrorTracker (D117), never
      raised. The body and the recipient addresses are never logged.

  It works from the struct it is given and never reads the database, so a
  user who deletes their account straight after submitting cannot crash it.
  """

  import Swoosh.Email

  alias TraysSocial.Feedback.Submission
  alias TraysSocial.Mailer

  require Logger

  @cap_bucket "feedback_notify:global"
  @cap_logged_bucket "feedback_notify:cap_logged"
  @cap_window_ms 60 * 60 * 1000
  @cap_max 30
  @excerpt_length 500
  @subject_text_length 80

  @doc false
  def cap_buckets, do: [@cap_bucket, @cap_logged_bucket]

  @doc """
  Sends the notification for `submission`.

  Returns `:ok` when every email was handed to the mailer, `:skipped` when
  no admin address is configured, `:capped` when the hourly cap is reached,
  or `{:error, reason}` when at least one email failed.
  """
  @spec notify_new_submission(Submission.t()) :: :ok | :skipped | :capped | {:error, term()}
  def notify_new_submission(%Submission{} = submission) do
    case recipients() do
      [] ->
        :skipped

      recipients ->
        if within_cap?(),
          do: deliver_all(submission, recipients),
          else: :capped
    end
  end

  defp recipients do
    :trays_social
    |> Application.get_env(:admin_emails, [])
    |> List.wrap()
    |> Enum.filter(&(is_binary(&1) and String.trim(&1) != ""))
  end

  defp within_cap? do
    if Application.get_env(:trays_social, :disable_rate_limiting, false) do
      true
    else
      case Hammer.check_rate(@cap_bucket, @cap_window_ms, @cap_max) do
        {:allow, _count} ->
          true

        {:deny, _limit} ->
          log_cap_once()
          false

        {:error, reason} ->
          # A broken limiter must not silence reports; send and say so.
          Logger.warning("feedback notification cap check failed: reason=#{inspect(reason)}")
          true
      end
    end
  end

  # A second one-per-window bucket makes the warning fire once per window
  # rather than once per extra submission.
  defp log_cap_once do
    case Hammer.check_rate(@cap_logged_bucket, @cap_window_ms, 1) do
      {:allow, _} ->
        Logger.warning(
          "feedback notification cap reached: #{@cap_max} per hour; " <>
            "further submissions this hour are stored without an email"
        )

      _ ->
        :ok
    end
  end

  defp deliver_all(submission, recipients) do
    subject = subject_line(submission)
    text = text_body(submission)

    results = Enum.map(recipients, &deliver(&1, subject, text, submission))

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> :ok
      error -> error
    end
  end

  defp deliver(recipient, subject, text, %Submission{id: id}) do
    from_email = Application.get_env(:trays_social, :mailer_from_email, "noreply@trays.social")

    email =
      new()
      |> to(recipient)
      |> from({"Trays", from_email})
      |> subject(subject)
      |> text_body(text)

    try do
      case Mailer.deliver(email) do
        {:ok, metadata} ->
          Logger.info(
            "feedback notification sent: submission_id=#{id} provider_id=#{inspect(metadata[:id])}"
          )

          :ok

        {:error, reason} ->
          report_failure(id, reason, RuntimeError.exception("email_delivery_failed"), [])
          {:error, reason}
      end
    rescue
      exception ->
        report_failure(id, exception, exception, __STACKTRACE__)
        {:error, exception}
    end
  end

  defp report_failure(id, reason, exception, stacktrace) do
    Logger.error("feedback notification failed: submission_id=#{id} reason=#{inspect(reason)}")

    ErrorTracker.report(exception, stacktrace, %{
      source: "feedback_notifier",
      submission_id: id,
      reason: inspect(reason)
    })
  end

  # User text in a header: control characters (CR and LF included) become
  # spaces so nothing can start a new header line, and the length is capped.
  defp subject_line(%Submission{kind: kind} = submission) do
    label = if kind == "bug", do: "bug report", else: "feedback"
    "[Trays] New #{label}: " <> subject_text(submission)
  end

  # The subject when it has visible text, else the start of the body: a
  # blank or control-character-only subject must not leave the line empty.
  defp subject_text(%Submission{subject: subject, body: body}) do
    case sanitize_header(subject) do
      "" -> sanitize_header(body)
      text -> text
    end
  end

  defp sanitize_header(text) when is_binary(text) do
    text
    |> String.replace(~r/[\x00-\x1F\x7F]+/u, " ")
    |> String.trim()
    |> String.slice(0, @subject_text_length)
  end

  defp sanitize_header(_), do: ""

  defp text_body(%Submission{} = s) do
    """
    A new #{s.kind} was submitted on Trays.

    Kind: #{s.kind}
    Platform: #{s.platform}
    App version: #{version(s)}
    OS: #{present(s.os_version)}
    Device: #{present(s.device_model)}
    Screen: #{present(s.screen)}
    Submission: ##{s.id} at #{s.inserted_at}

    Subject: #{present(s.subject)}

    #{excerpt(s.body)}

    Open it in the admin viewer:
    #{admin_url(s)}
    """
  end

  defp version(%Submission{app_version: nil, app_build: nil}), do: "unknown"
  defp version(%Submission{app_version: v, app_build: nil}), do: v
  defp version(%Submission{app_version: nil, app_build: b}), do: "unknown (#{b})"
  defp version(%Submission{app_version: v, app_build: b}), do: "#{v} (#{b})"

  defp present(nil), do: "unknown"
  defp present(""), do: "unknown"
  defp present(value), do: value

  defp excerpt(nil), do: ""

  defp excerpt(body) do
    if String.length(body) > @excerpt_length,
      do: String.slice(body, 0, @excerpt_length) <> "...",
      else: body
  end

  defp admin_url(%Submission{id: id}),
    do: TraysSocialWeb.Endpoint.url() <> "/admin/feedback/#{id}"
end
