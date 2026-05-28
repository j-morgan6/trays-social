defmodule TraysSocial.Feedback do
  @moduledoc """
  Storage + admin-side read access for in-app feedback submissions
  (W123 / G27).

  Mirrors the `TraysSocial.Diagnostics` pattern from W117: a thin
  context module wrapping Repo calls. The iOS form posts here via
  `POST /api/v1/feedback`; the admin viewer at `/admin/feedback`
  (W124) reads via `list_recent/1` and updates status via
  `mark_triaged/1` / `mark_resolved/1`.
  """

  import Ecto.Query, warn: false

  alias TraysSocial.Feedback.Submission
  alias TraysSocial.Repo

  @doc """
  Inserts a new submission. `attrs` accepts string or atom keys (the
  controller passes the JSON body through plus `user_id` from
  `current_user`).
  """
  def submit(attrs) do
    %Submission{}
    |> Submission.submit_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists submissions newest first.

  ## Options

    * `:limit` — page size (default 50)
    * `:status` — filter to "new" / "triaged" / "resolved"
  """
  def list_recent(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Submission
    |> maybe_filter_status(opts[:status])
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

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, ""), do: query

  defp maybe_filter_status(query, status) when is_binary(status),
    do: where(query, [s], s.status == ^status)
end
