defmodule TraysSocialWeb.Admin.IosCrashesLive do
  @moduledoc """
  Admin view of MetricKit diagnostic payloads from iOS clients.

  Two live actions:

    * `:index` (`/admin/ios-crashes`) — list view with filters by
      payload_type, app_version, and device_model.
    * `:show`  (`/admin/ios-crashes/:id`) — detail view with the raw
      Apple payload pretty-printed.

  The list view never renders the raw JSON — it only shows extracted
  top-level columns. Pretty-printing happens lazily on click so a 100KB
  payload doesn't slow the index render down.

  Gated by the surrounding `/admin` scope's pipeline
  (require_authenticated_user + RequireAdmin) plus the same defense-in-
  depth `on_mount {RequireAdmin, :ensure_admin}` hook used by
  ReportsLive — so a future scope refactor doesn't accidentally expose
  the page.
  """

  use TraysSocialWeb, :live_view

  alias TraysSocial.Diagnostics
  alias TraysSocial.Diagnostics.IosDiagnosticPayload

  on_mount {TraysSocialWeb.UserAuth, :require_authenticated_user}
  on_mount {TraysSocialWeb.Plugs.RequireAdmin, :ensure_admin}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "iOS crashes")
     |> assign(:filter_payload_type, "")
     |> assign(:filter_app_version, "")
     |> assign(:filter_device_model, "")
     |> assign(:payload_types, IosDiagnosticPayload.payload_types())
     |> assign(:app_versions, Diagnostics.distinct_values(:app_version))
     |> assign(:device_models, Diagnostics.distinct_values(:device_model))
     |> assign(:payloads, [])
     |> assign(:selected, nil)
     |> assign_payloads()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      case params["id"] do
        nil -> assign(socket, :selected, nil)
        id -> assign(socket, :selected, Diagnostics.get_payload!(id))
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply,
     socket
     |> assign(:filter_payload_type, params["payload_type"] || "")
     |> assign(:filter_app_version, params["app_version"] || "")
     |> assign(:filter_device_model, params["device_model"] || "")
     |> assign_payloads()}
  end

  defp assign_payloads(socket) do
    payloads =
      Diagnostics.list_recent(
        payload_type: presence(socket.assigns.filter_payload_type),
        app_version: presence(socket.assigns.filter_app_version),
        device_model: presence(socket.assigns.filter_device_model)
      )

    assign(socket, :payloads, payloads)
  end

  defp presence(""), do: nil
  defp presence(nil), do: nil
  defp presence(v), do: v

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl p-6 space-y-6">
      <header class="space-y-1">
        <h1 class="text-2xl font-semibold">iOS crashes</h1>
        <p class="text-sm text-base-content/70">
          MetricKit payloads delivered by user devices. Diagnostic payloads
          arrive on next launch after a crash, hang, or CPU/disk exception;
          metric payloads arrive roughly once per day per device. Click a
          row to see the raw Apple payload.
        </p>
      </header>

      <form phx-change="filter" class="flex flex-wrap items-end gap-3">
        <div class="flex flex-col gap-1">
          <label for="filter-payload-type" class="text-xs font-medium">Type</label>
          <select
            id="filter-payload-type"
            name="payload_type"
            class="select select-bordered select-sm"
          >
            <option value="">All</option>
            <option :for={t <- @payload_types} value={t} selected={t == @filter_payload_type}>
              {t}
            </option>
          </select>
        </div>

        <div class="flex flex-col gap-1">
          <label for="filter-app-version" class="text-xs font-medium">App version</label>
          <select
            id="filter-app-version"
            name="app_version"
            class="select select-bordered select-sm"
          >
            <option value="">All</option>
            <option :for={v <- @app_versions} value={v} selected={v == @filter_app_version}>
              {v}
            </option>
          </select>
        </div>

        <div class="flex flex-col gap-1">
          <label for="filter-device-model" class="text-xs font-medium">Device model</label>
          <select
            id="filter-device-model"
            name="device_model"
            class="select select-bordered select-sm"
          >
            <option value="">All</option>
            <option :for={m <- @device_models} value={m} selected={m == @filter_device_model}>
              {m}
            </option>
          </select>
        </div>

        <p class="ml-auto text-xs text-base-content/60">{length(@payloads)} payload(s)</p>
      </form>

      <div :if={@selected} class="border border-base-300 rounded-lg p-4 bg-base-200 space-y-3">
        <div class="flex items-start gap-3">
          <div class="flex-1 space-y-1">
            <h2 class="text-lg font-semibold">Payload #{@selected.id}</h2>
            <dl class="grid grid-cols-2 gap-x-6 gap-y-1 text-sm">
              <div>
                <dt class="text-xs uppercase tracking-wide text-base-content/60">Type</dt>
                <dd class="font-mono">{@selected.payload_type}</dd>
              </div>
              <div>
                <dt class="text-xs uppercase tracking-wide text-base-content/60">Received</dt>
                <dd class="font-mono text-xs">{format_ts(@selected.received_at)}</dd>
              </div>
              <div>
                <dt class="text-xs uppercase tracking-wide text-base-content/60">App version</dt>
                <dd class="font-mono">{@selected.app_version || "—"}</dd>
              </div>
              <div>
                <dt class="text-xs uppercase tracking-wide text-base-content/60">OS version</dt>
                <dd class="font-mono">{@selected.os_version || "—"}</dd>
              </div>
              <div>
                <dt class="text-xs uppercase tracking-wide text-base-content/60">Device</dt>
                <dd class="font-mono">{@selected.device_model || "—"}</dd>
              </div>
              <div>
                <dt class="text-xs uppercase tracking-wide text-base-content/60">User ID</dt>
                <dd class="font-mono">{@selected.user_id || "anon"}</dd>
              </div>
            </dl>
          </div>
          <.link patch={~p"/admin/ios-crashes"} class="btn btn-sm btn-ghost">Close</.link>
        </div>

        <pre class="bg-base-100 rounded p-3 text-xs overflow-x-auto max-h-[60vh]">{pretty_json(@selected.payload)}</pre>
      </div>

      <div class="overflow-x-auto">
        <table class="table table-sm">
          <thead>
            <tr>
              <th>Received</th>
              <th>Type</th>
              <th>App</th>
              <th>OS</th>
              <th>Device</th>
              <th>User</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={p <- @payloads}>
              <td class="font-mono text-xs whitespace-nowrap">{format_ts(p.received_at)}</td>
              <td>
                <span class={"badge badge-sm " <> badge_for(p.payload_type)}>
                  {p.payload_type}
                </span>
              </td>
              <td class="font-mono text-xs">{p.app_version || "—"}</td>
              <td class="font-mono text-xs">{p.os_version || "—"}</td>
              <td class="font-mono text-xs">{p.device_model || "—"}</td>
              <td class="font-mono text-xs">{p.user_id || "anon"}</td>
              <td>
                <.link patch={~p"/admin/ios-crashes/#{p.id}"} class="btn btn-xs btn-ghost">
                  Open
                </.link>
              </td>
            </tr>
            <tr :if={@payloads == []}>
              <td colspan="7" class="text-center text-sm text-base-content/60 py-6">
                No payloads. iOS clients only post after MetricKit delivers
                a diagnostic (next launch after a crash) or once per day per
                device for metric payloads.
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

  defp pretty_json(payload) do
    Jason.encode!(payload, pretty: true)
  rescue
    _ -> inspect(payload, pretty: true)
  end

  defp badge_for("diagnostic"), do: "badge-error"
  defp badge_for("metric"), do: "badge-info"
  defp badge_for(_), do: "badge-ghost"
end
