defmodule TraysSocialWeb.Admin.EmailEventsLive do
  @moduledoc """
  Admin view of recent Resend webhook events. Recipient and event type
  filters; click an email_id to show the full event chain for that send.

  Gated by the surrounding /admin scope's require_authenticated_user +
  RequireAdmin pipeline (see router.ex). The recipient column is PII;
  this view is the only place it should be displayed.
  """

  use TraysSocialWeb, :live_view

  alias TraysSocial.Email

  @event_types ~w(
    email.sent
    email.delivered
    email.bounced
    email.complained
    email.delivery_delayed
    email.opened
    email.clicked
  )

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Email events")
     |> assign(:event_types, @event_types)
     |> assign(:filter_event_type, "")
     |> assign(:filter_recipient, "")
     |> assign(:events, Email.list_recent_events())}
  end

  @impl true
  def handle_event("filter", params, socket) do
    event_type = Map.get(params, "event_type", "")
    recipient = Map.get(params, "recipient", "")

    events =
      Email.list_recent_events(
        event_type: event_type,
        recipient: recipient
      )

    {:noreply,
     socket
     |> assign(:filter_event_type, event_type)
     |> assign(:filter_recipient, recipient)
     |> assign(:events, events)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl p-6 space-y-6">
      <header class="space-y-1">
        <h1 class="text-2xl font-semibold">Email events</h1>
        <p class="text-sm text-base-content/70">
          Recent Resend webhook deliveries. Idempotent by event_id — retries from
          Resend are not double-counted. Use this view to diagnose silent
          deliverability failures: a send with no follow-up delivered/bounced/
          dropped event after ~5 minutes is suspicious.
        </p>
      </header>

      <form phx-change="filter" class="flex flex-wrap items-end gap-3">
        <div class="flex flex-col gap-1">
          <label for="filter-event-type" class="text-xs font-medium">Event type</label>
          <select
            id="filter-event-type"
            name="event_type"
            class="select select-bordered select-sm"
          >
            <option value="">All</option>
            <option :for={t <- @event_types} value={t} selected={t == @filter_event_type}>
              {t}
            </option>
          </select>
        </div>

        <div class="flex flex-col gap-1">
          <label for="filter-recipient" class="text-xs font-medium">Recipient contains</label>
          <input
            id="filter-recipient"
            type="text"
            name="recipient"
            value={@filter_recipient}
            placeholder="@privaterelay.appleid.com"
            phx-debounce="250"
            class="input input-bordered input-sm"
          />
        </div>

        <p class="ml-auto text-xs text-base-content/60">{length(@events)} event(s)</p>
      </form>

      <div class="overflow-x-auto">
        <table class="table table-sm">
          <thead>
            <tr>
              <th>When</th>
              <th>Event</th>
              <th>Recipient</th>
              <th>Email ID</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={event <- @events}>
              <td class="font-mono text-xs whitespace-nowrap">
                {format_ts(event.inserted_at)}
              </td>
              <td>
                <span class={"badge badge-sm " <> badge_for(event.event_type)}>
                  {event.event_type}
                </span>
              </td>
              <td class="font-mono text-xs">{event.recipient}</td>
              <td class="font-mono text-xs">{event.email_id}</td>
            </tr>
            <tr :if={@events == []}>
              <td colspan="4" class="text-center text-sm text-base-content/60 py-6">
                No events. If you expected one, check the webhook configuration in
                the Resend dashboard and confirm <code>RESEND_WEBHOOK_SIGNING_SECRET</code>
                is set on this environment.
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp format_ts(%DateTime{} = ts) do
    ts |> DateTime.truncate(:second) |> DateTime.to_iso8601()
  end

  defp format_ts(_), do: "—"

  defp badge_for("email.delivered"), do: "badge-success"
  defp badge_for("email.opened"), do: "badge-info"
  defp badge_for("email.clicked"), do: "badge-info"
  defp badge_for("email.bounced"), do: "badge-error"
  defp badge_for("email.complained"), do: "badge-error"
  defp badge_for("email.delivery_delayed"), do: "badge-warning"
  defp badge_for(_), do: "badge-ghost"
end
