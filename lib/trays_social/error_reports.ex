defmodule TraysSocial.ErrorReports do
  @moduledoc """
  D120: retention and clean-up for the ErrorTracker tables
  (`error_tracker_errors`, `error_tracker_occurrences`).

  ErrorTracker's own `Plugins.Pruner` only removes errors marked resolved, so
  unresolved reports would be kept forever. The Privacy Policy promises that
  server logs are kept for no more than 30 days, so `prune/1` deletes every
  occurrence older than the retention window, whatever its status, and then
  the errors left with no occurrences. `TraysSocial.ErrorReports.Pruner` runs it
  on a timer; `TraysSocial.Release.prune_error_reports/0` runs it on demand.

  `scrub/1` cleans reports stored before D120: it re-applies
  `TraysSocial.ErrorReports.Filter` to their contexts and re-fires the
  database trigger that redacts stored exception messages. See docs/error-reports-retention.md.

  Both functions log counts only, never the stored context.
  """
  import Ecto.Query

  alias ErrorTracker.Error
  alias ErrorTracker.Occurrence
  alias TraysSocial.ErrorReports.Filter
  alias TraysSocial.Repo

  require Logger

  @default_batch_size 1_000

  @doc """
  Deletes ErrorTracker occurrences older than the retention window, in batches,
  then deletes errors that have no occurrences left.

  An error is only deleted when its `last_occurrence_at` is also before the
  cutoff, so an error that is being reported right now (upserted, occurrence
  not yet visible) is never removed. Every delete is idempotent, so two
  machines running the prune at once is harmless.

  Options (for tests and one-off operator runs; production reads config):

    * `:retention_days` — days to keep. Defaults to
      `config :trays_social, :error_reports, retention_days:`. Must be a
      positive integer, otherwise raises `ArgumentError`.
    * `:now` — the reference time. Defaults to `DateTime.utc_now/0`.
    * `:batch_size` — occurrences deleted per statement. Defaults to 1000.

  Returns `{:ok, %{occurrences: n, errors: m}}` and logs both counts at `:info`.
  """
  def prune(opts \\ []) do
    retention_days = Keyword.get_lazy(opts, :retention_days, &configured_retention_days/0)
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)

    unless is_integer(retention_days) and retention_days >= 1 do
      raise ArgumentError,
            "error_reports retention_days must be a positive integer, got: " <>
              inspect(retention_days)
    end

    cutoff = DateTime.add(now, -retention_days, :day)

    occurrences = delete_old_occurrences(cutoff, batch_size, 0)

    {errors, _} =
      from(e in Error,
        as: :error,
        where: e.last_occurrence_at < ^cutoff,
        where: not exists(from(o in Occurrence, where: o.error_id == parent_as(:error).id))
      )
      |> Repo.delete_all()

    Logger.info(
      "error_reports prune: occurrences=#{occurrences} errors=#{errors} " <>
        "cutoff=#{DateTime.to_iso8601(cutoff)} retention_days=#{retention_days}"
    )

    {:ok, %{occurrences: occurrences, errors: errors}}
  end

  defp delete_old_occurrences(cutoff, batch_size, total) do
    ids =
      from(o in Occurrence,
        where: o.inserted_at < ^cutoff,
        order_by: o.id,
        limit: ^batch_size,
        select: o.id
      )
      |> Repo.all()

    case ids do
      [] ->
        total

      ids ->
        {deleted, _} = from(o in Occurrence, where: o.id in ^ids) |> Repo.delete_all()
        delete_old_occurrences(cutoff, batch_size, total + deleted)
    end
  end

  @doc """
  Cleans error reports stored before D120: re-applies
  `TraysSocial.ErrorReports.Filter` to every occurrence's context (rewriting
  only the rows that change), and re-fires the `trays_redact_error_reason`
  database trigger on every stored exception message (`reason`) on occurrences
  and errors by setting it to itself. Walks each table by id in batches, so it
  is safe on a large table and safe to re-run.

  Options: `:batch_size` (default 1000).

  Returns `{:ok, %{scanned: n, scrubbed: m, reasons_rechecked: r}}` and logs
  the counts at `:info`.
  """
  def scrub(opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)

    {scanned, scrubbed} = scrub_contexts(0, batch_size, {0, 0})

    reasons =
      recheck_reasons(Occurrence, 0, batch_size, 0) + recheck_reasons(Error, 0, batch_size, 0)

    Logger.info(
      "error_reports scrub: scanned=#{scanned} scrubbed=#{scrubbed} reasons_rechecked=#{reasons}"
    )

    {:ok, %{scanned: scanned, scrubbed: scrubbed, reasons_rechecked: reasons}}
  end

  defp scrub_contexts(last_id, batch_size, {scanned, scrubbed}) do
    rows =
      from(o in Occurrence,
        where: o.id > ^last_id,
        order_by: o.id,
        limit: ^batch_size,
        select: {o.id, o.context}
      )
      |> Repo.all()

    case rows do
      [] ->
        {scanned, scrubbed}

      rows ->
        changed =
          for {id, context} <- rows,
              sanitized = Filter.sanitize(context),
              sanitized != context,
              reduce: 0 do
            count ->
              from(o in Occurrence, where: o.id == ^id)
              |> Repo.update_all(set: [context: sanitized])

              count + 1
          end

        {last, _} = List.last(rows)
        scrub_contexts(last, batch_size, {scanned + length(rows), scrubbed + changed})
    end
  end

  # `UPDATE ... SET reason = reason` fires the BEFORE UPDATE OF reason trigger
  # (migration 20261104120100), which redacts the stored message in place.
  defp recheck_reasons(schema, last_id, batch_size, total) do
    ids =
      from(r in schema,
        where: r.id > ^last_id and not is_nil(r.reason),
        order_by: r.id,
        limit: ^batch_size,
        select: r.id
      )
      |> Repo.all()

    case ids do
      [] ->
        total

      ids ->
        {touched, _} =
          from(r in schema, where: r.id in ^ids, update: [set: [reason: r.reason]])
          |> Repo.update_all([])

        recheck_reasons(schema, List.last(ids), batch_size, total + touched)
    end
  end

  defp configured_retention_days do
    :trays_social
    |> Application.get_env(:error_reports, [])
    |> Keyword.get(:retention_days)
  end
end
