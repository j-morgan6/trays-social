defmodule TraysSocial.Feedback do
  @moduledoc """
  Storage, admin-side read access and the developer notification for
  in-app bug reports and feedback (W123 / G27, extended in W260).

  A thin context module wrapping Repo calls. The iOS form posts here via
  `POST /api/v1/feedback`; the admin viewer at `/admin/feedback` (W124)
  reads via `list_recent/1` and updates status via `mark_triaged/1` /
  `mark_resolved/1`.

  ## What a submission stores

  `kind` (`bug` or `feedback`, default `feedback`), `platform` (`ios` or
  `web`, default `ios`), `subject`, `body`, `app_version`, `app_build`,
  `os_version`, `device_model`, `screen` and `user_agent`, plus the owning
  user and a triage `status`. See `TraysSocial.Feedback.Submission` for the
  length limits. No IP address is stored. A submission belongs to the
  account and is deleted with it (D103).

  ## Developer notification

  `submit/2` stores the row first, then hands it to
  `TraysSocial.Feedback.Notifier`, which emails every address in
  `config :trays_social, :admin_emails` from a supervised task. The email
  is best effort: it never fails or delays the submission, at most 30 are
  sent per hour (later rows are only stored), and a send failure is logged
  and reported to ErrorTracker (D117).
  """

  import Ecto.Query, warn: false

  alias TraysSocial.Accounts.User
  alias TraysSocial.Feedback.Notifier
  alias TraysSocial.Feedback.Submission
  alias TraysSocial.Repo

  @doc """
  Stores a submission for `user`, then notifies the developer.

  `attrs` accepts string or atom keys. The owner comes only from `user`
  (D44/D52): any `user_id` in `attrs` is ignored.

  The notification runs under `TraysSocial.MailerTaskSupervisor` after the
  insert, so its outcome never reaches the caller. D106: `start_child`,
  never `async_nolink`, so the caller's mailbox stays untouched.
  """
  @spec submit(User.t(), map()) :: {:ok, Submission.t()} | {:error, Ecto.Changeset.t()}
  def submit(%User{} = user, attrs) when is_map(attrs) do
    %Submission{user_id: user.id}
    |> Submission.submit_changeset(attrs)
    |> Repo.insert()
    |> tap(fn
      {:ok, submission} -> notify(submission)
      {:error, _changeset} -> :ok
    end)
  end

  defp notify(%Submission{} = submission) do
    _ =
      Task.Supervisor.start_child(TraysSocial.MailerTaskSupervisor, fn ->
        Notifier.notify_new_submission(submission)
      end)

    :ok
  end

  @doc """
  Lists submissions newest first.

  ## Options

    * `:limit` - page size (default 50)
    * `:status` - filter to "new" / "triaged" / "resolved"
    * `:kind` - filter to "bug" / "feedback"
    * `:platform` - filter to "ios" / "web"

  A `nil` or `""` filter value is ignored.
  """
  def list_recent(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Submission
    |> maybe_filter(:status, opts[:status])
    |> maybe_filter(:kind, opts[:kind])
    |> maybe_filter(:platform, opts[:platform])
    |> order_by([s], desc: s.inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
  end

  @doc "Fetch a submission by id; raises on miss."
  def get_submission!(id), do: Submission |> preload(:user) |> Repo.get!(id)

  def mark_triaged(%Submission{} = submission),
    do: submission |> Submission.status_changeset("triaged") |> Repo.update()

  def mark_resolved(%Submission{} = submission),
    do: submission |> Submission.status_changeset("resolved") |> Repo.update()

  defp maybe_filter(query, _field, nil), do: query
  defp maybe_filter(query, _field, ""), do: query

  defp maybe_filter(query, field, value) when is_binary(value),
    do: where(query, [s], field(s, ^field) == ^value)
end
