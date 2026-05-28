defmodule TraysSocialWeb.Admin.FeedbackLive do
  @moduledoc """
  Admin view of in-app feedback submissions (W124 / G27).

  Mirrors `Admin.IosCrashesLive` (W118): one module owns both
  `:index` (`/admin/feedback`) and `:show`
  (`/admin/feedback/:id`) via handle_params switching on the
  optional `id`. List view shows submitter / subject / status badge /
  app / received_at. Detail panel pulls the full body and offers
  Mark Triaged + Mark Resolved actions.

  Defense-in-depth admin gate: router pipeline plus the
  `on_mount {RequireAdmin, :ensure_admin}` hook used by ReportsLive +
  IosCrashesLive.
  """

  use TraysSocialWeb, :live_view

  alias TraysSocial.Feedback
  alias TraysSocial.Feedback.Submission

  on_mount {TraysSocialWeb.UserAuth, :require_authenticated_user}
  on_mount {TraysSocialWeb.Plugs.RequireAdmin, :ensure_admin}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Feedback")
     |> assign(:filter_status, "")
     |> assign(:statuses, Submission.statuses())
     |> assign(:submissions, [])
     |> assign(:selected, nil)
     |> assign_submissions()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      case params["id"] do
        nil -> assign(socket, :selected, nil)
        id -> assign(socket, :selected, Feedback.get_submission!(id))
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply,
     socket
     |> assign(:filter_status, params["status"] || "")
     |> assign_submissions()}
  end

  @impl true
  def handle_event("mark_triaged", %{"id" => id}, socket) do
    {:ok, _} = id |> Feedback.get_submission!() |> Feedback.mark_triaged()
    {:noreply, reload(socket, id)}
  end

  @impl true
  def handle_event("mark_resolved", %{"id" => id}, socket) do
    {:ok, _} = id |> Feedback.get_submission!() |> Feedback.mark_resolved()
    {:noreply, reload(socket, id)}
  end

  defp reload(socket, id) do
    socket
    |> assign(:selected, Feedback.get_submission!(id))
    |> assign_submissions()
  end

  defp assign_submissions(socket) do
    submissions =
      Feedback.list_recent(status: presence(socket.assigns.filter_status))

    assign(socket, :submissions, submissions)
  end

  defp presence(""), do: nil
  defp presence(nil), do: nil
  defp presence(v), do: v

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl p-6 space-y-6">
      <header class="space-y-1">
        <h1 class="text-2xl font-semibold">Feedback</h1>
        <p class="text-sm text-base-content/70">
          In-app feedback submissions from authenticated users. Triage with
          the Mark Triaged and Mark Resolved actions on the detail panel.
        </p>
      </header>

      <form phx-change="filter" class="flex flex-wrap items-end gap-3">
        <div class="flex flex-col gap-1">
          <label for="filter-status" class="text-xs font-medium">Status</label>
          <select
            id="filter-status"
            name="status"
            class="select select-bordered select-sm"
          >
            <option value="">All</option>
            <option :for={s <- @statuses} value={s} selected={s == @filter_status}>
              {s}
            </option>
          </select>
        </div>

        <p class="ml-auto text-xs text-base-content/60">{length(@submissions)} submission(s)</p>
      </form>

      <div :if={@selected} class="border border-base-300 rounded-lg p-4 bg-base-200 space-y-3">
        <div class="flex items-start gap-3">
          <div class="flex-1 space-y-1">
            <h2 class="text-lg font-semibold">Submission #{@selected.id}</h2>
            <dl class="grid grid-cols-2 gap-x-6 gap-y-1 text-sm">
              <div>
                <dt class="text-xs uppercase tracking-wide text-base-content/60">From</dt>
                <dd class="font-mono">@{@selected.user.username}</dd>
              </div>
              <div>
                <dt class="text-xs uppercase tracking-wide text-base-content/60">Received</dt>
                <dd class="font-mono text-xs">{format_ts(@selected.inserted_at)}</dd>
              </div>
              <div>
                <dt class="text-xs uppercase tracking-wide text-base-content/60">Status</dt>
                <dd>
                  <span class={"badge badge-sm " <> badge_for(@selected.status)}>
                    {@selected.status}
                  </span>
                </dd>
              </div>
              <div>
                <dt class="text-xs uppercase tracking-wide text-base-content/60">App / OS / Device</dt>
                <dd class="font-mono text-xs">
                  {@selected.app_version || "—"} / {@selected.os_version || "—"} / {@selected.device_model || "—"}
                </dd>
              </div>
            </dl>
            <div :if={@selected.subject} class="pt-2">
              <dt class="text-xs uppercase tracking-wide text-base-content/60">Subject</dt>
              <dd class="font-medium">{@selected.subject}</dd>
            </div>
          </div>
          <.link patch={~p"/admin/feedback"} class="btn btn-sm btn-ghost">Close</.link>
        </div>

        <div>
          <div class="text-xs uppercase tracking-wide text-base-content/60 mb-1">Body</div>
          <pre class="bg-base-100 rounded p-3 text-sm whitespace-pre-wrap break-words max-h-[50vh] overflow-y-auto">{@selected.body}</pre>
        </div>

        <div class="flex gap-2">
          <button
            :if={@selected.status != "triaged"}
            type="button"
            phx-click="mark_triaged"
            phx-value-id={@selected.id}
            class="btn btn-sm btn-outline"
          >
            Mark triaged
          </button>
          <button
            :if={@selected.status != "resolved"}
            type="button"
            phx-click="mark_resolved"
            phx-value-id={@selected.id}
            class="btn btn-sm btn-primary"
          >
            Mark resolved
          </button>
        </div>
      </div>

      <div class="overflow-x-auto">
        <table class="table table-sm">
          <thead>
            <tr>
              <th>Received</th>
              <th>From</th>
              <th>Subject</th>
              <th>Status</th>
              <th>App</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={s <- @submissions}>
              <td class="font-mono text-xs whitespace-nowrap">{format_ts(s.inserted_at)}</td>
              <td class="font-mono text-xs">@{s.user.username}</td>
              <td>{truncate(s.subject || first_line(s.body), 80)}</td>
              <td>
                <span class={"badge badge-sm " <> badge_for(s.status)}>{s.status}</span>
              </td>
              <td class="font-mono text-xs">{s.app_version || "—"}</td>
              <td>
                <.link patch={~p"/admin/feedback/#{s.id}"} class="btn btn-xs btn-ghost">
                  Open
                </.link>
              </td>
            </tr>
            <tr :if={@submissions == []}>
              <td colspan="6" class="text-center text-sm text-base-content/60 py-6">
                No feedback submitted yet.
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

  defp first_line(nil), do: ""
  defp first_line(body), do: body |> String.split("\n") |> hd()

  defp truncate(nil, _), do: ""

  defp truncate(text, max) when is_binary(text) do
    if String.length(text) <= max, do: text, else: String.slice(text, 0, max - 1) <> "…"
  end

  defp badge_for("new"), do: "badge-info"
  defp badge_for("triaged"), do: "badge-warning"
  defp badge_for("resolved"), do: "badge-success"
  defp badge_for(_), do: "badge-ghost"
end
