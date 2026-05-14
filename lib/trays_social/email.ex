defmodule TraysSocial.Email do
  @moduledoc """
  Context module for email deliverability telemetry — specifically the
  email_events table populated by Resend webhook deliveries.
  """

  import Ecto.Query

  alias TraysSocial.Email.Event
  alias TraysSocial.Repo

  @doc """
  Inserts a webhook event, idempotently. Repeat invocations with the same
  `event_id` are no-ops (the unique index on `event_id` plus
  `on_conflict: :nothing` returns the existing row's id without raising or
  duplicating data — important because Resend retries on 5xx).

  Returns `{:ok, event}` on success (including idempotent no-ops, in which
  case `event.id` is the original row's id). Returns `{:error, changeset}`
  on validation failure.
  """
  def upsert_event(attrs) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing, conflict_target: :event_id)
  end

  @doc """
  Lists the most recent events with optional filtering by event_type or
  recipient substring. Default limit is 200 — admin view paginates
  manually if needed later.

  Options:
    * `:limit` — integer cap (default 200)
    * `:event_type` — exact string match (e.g. `"email.bounced"`); nil = all
    * `:recipient` — case-insensitive substring; nil = all
  """
  def list_recent_events(opts \\ []) do
    limit = Keyword.get(opts, :limit, 200)
    event_type = Keyword.get(opts, :event_type)
    recipient = Keyword.get(opts, :recipient)

    Event
    |> maybe_filter_event_type(event_type)
    |> maybe_filter_recipient(recipient)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  defp maybe_filter_event_type(query, nil), do: query
  defp maybe_filter_event_type(query, ""), do: query

  defp maybe_filter_event_type(query, event_type) when is_binary(event_type) do
    from e in query, where: e.event_type == ^event_type
  end

  defp maybe_filter_recipient(query, nil), do: query
  defp maybe_filter_recipient(query, ""), do: query

  defp maybe_filter_recipient(query, recipient) when is_binary(recipient) do
    pattern = "%" <> String.downcase(recipient) <> "%"
    from e in query, where: fragment("lower(?) like ?", e.recipient, ^pattern)
  end
end
