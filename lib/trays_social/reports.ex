defmodule TraysSocial.Reports do
  import Ecto.Query
  alias TraysSocial.Accounts.User
  alias TraysSocial.Repo
  alias TraysSocial.Reports.Report

  # D52: reporter is passed positionally and seeded into the struct before
  # the changeset runs, so a client-supplied `reporter_id` in attrs is
  # silently dropped (Report.changeset has it stripped from cast). Closes
  # the pre-claim IDOR — an attacker can't forge reporter_id and trip the
  # unique [reporter_id, target_type, target_id] constraint to silence a
  # legitimate user's report.
  def create_report(%User{} = reporter, attrs) do
    %Report{reporter_id: reporter.id}
    |> Report.changeset(attrs)
    |> Repo.insert()
  end

  def list_open_reports do
    Report
    |> where([r], r.status == "open")
    |> order_by([r], desc: r.inserted_at)
    |> preload(:reporter)
    |> Repo.all()
  end

  def list_reports(opts \\ []) do
    status = Keyword.get(opts, :status)

    Report
    |> then(fn q ->
      if status, do: where(q, [r], r.status == ^status), else: q
    end)
    |> order_by([r], desc: r.inserted_at)
    |> preload(:reporter)
    |> Repo.all()
  end

  def get_report!(id) do
    Report
    |> preload(:reporter)
    |> Repo.get!(id)
  end

  def resolve_report(report, %{status: status, resolved_by_id: resolved_by_id}) do
    report
    |> Report.resolve_changeset(%{
      status: status,
      resolved_at: DateTime.utc_now() |> DateTime.truncate(:second),
      resolved_by_id: resolved_by_id
    })
    |> Repo.update()
  end
end
