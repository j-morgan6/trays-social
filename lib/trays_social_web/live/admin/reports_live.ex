defmodule TraysSocialWeb.Admin.ReportsLive do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Posts
  alias TraysSocial.Reports

  # D55: defense-in-depth admin gate. The router pipeline already enforces
  # admin (RequireAdmin), but pinning it at the LiveView module keeps the
  # check from drifting if a future live_session refactor moves things
  # around. Reuses the existing :ensure_admin hook on RequireAdmin so
  # there's only one definition of "what counts as admin".
  on_mount {TraysSocialWeb.UserAuth, :require_authenticated_user}
  on_mount {TraysSocialWeb.Plugs.RequireAdmin, :ensure_admin}

  @impl true
  def mount(_params, _session, socket) do
    reports = Reports.list_reports()

    {:ok,
     socket
     |> assign(:reports, reports)
     |> assign(:filter, "all")}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    reports =
      if status == "all",
        do: Reports.list_reports(),
        else: Reports.list_reports(status: status)

    {:noreply, assign(socket, reports: reports, filter: status)}
  end

  @impl true
  def handle_event("resolve", %{"id" => id, "status" => status}, socket) do
    report = Reports.get_report!(id)
    current_user = socket.assigns.current_scope.user

    {:ok, _} = Reports.resolve_report(report, %{status: status, resolved_by_id: current_user.id})

    reports =
      if socket.assigns.filter == "all",
        do: Reports.list_reports(),
        else: Reports.list_reports(status: socket.assigns.filter)

    {:noreply, assign(socket, :reports, reports)}
  end

  @impl true
  def handle_event("remove_post", %{"id" => id}, socket) do
    report = Reports.get_report!(id)
    current_user = socket.assigns.current_scope.user

    if report.target_type == "post" do
      post = Posts.get_post!(report.target_id)
      Posts.remove_post(post, %{removed_by_id: current_user.id, reason: report.reason})
    end

    {:ok, _} = Reports.resolve_report(report, %{status: "resolved", resolved_by_id: current_user.id})

    reports =
      if socket.assigns.filter == "all",
        do: Reports.list_reports(),
        else: Reports.list_reports(status: socket.assigns.filter)

    {:noreply, assign(socket, :reports, reports)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6">
      <nav class="flex gap-4 mb-6 text-sm border-b pb-3">
        <.link navigate={~p"/admin/reports"} class="font-semibold underline">Reports</.link>
        <.link navigate={~p"/admin/errors"} class="text-base-content/70 hover:underline">
          Errors
        </.link>
        <.link navigate={~p"/admin/dashboard"} class="text-base-content/70 hover:underline">
          Dashboard
        </.link>
      </nav>
      <h1 class="text-2xl font-bold mb-6">Reports</h1>

      <div class="flex gap-2 mb-6">
        <button
          :for={status <- ["all", "open", "reviewing", "resolved", "dismissed"]}
          phx-click="filter"
          phx-value-status={status}
          class={"px-3 py-1 rounded-full text-sm #{if @filter == status, do: "bg-emerald-600 text-white", else: "bg-base-200"}"}
        >
          {String.capitalize(status)}
        </button>
      </div>

      <div class="space-y-4">
        <div :for={report <- @reports} class="card bg-base-100 shadow p-4">
          <div class="flex justify-between items-start">
            <div>
              <span class="badge badge-outline">{report.target_type}</span>
              <span class="badge badge-warning ml-1">{report.reason}</span>
              <span class={"badge ml-1 #{status_color(report.status)}"}>{report.status}</span>
            </div>
            <span class="text-sm text-base-content/60">
              {Calendar.strftime(report.inserted_at, "%Y-%m-%d %H:%M")}
            </span>
          </div>

          <p class="mt-2 text-sm">
            <strong>Reporter:</strong> {report.reporter.username} |
            <strong>Target ID:</strong> {report.target_id}
          </p>

          <p :if={report.details} class="mt-1 text-sm text-base-content/70">{report.details}</p>

          <div :if={report.status == "open"} class="mt-3 flex gap-2">
            <button :if={report.target_type == "post"} phx-click="remove_post" phx-value-id={report.id}
              class="btn btn-sm btn-error">Remove Post</button>
            <button phx-click="resolve" phx-value-id={report.id} phx-value-status="resolved"
              class="btn btn-sm btn-success">Resolve</button>
            <button phx-click="resolve" phx-value-id={report.id} phx-value-status="dismissed"
              class="btn btn-sm btn-ghost">Dismiss</button>
          </div>
        </div>

        <p :if={@reports == []} class="text-center text-base-content/60 py-8">
          No reports found
        </p>
      </div>
    </div>
    """
  end

  defp status_color("open"), do: "badge-error"
  defp status_color("reviewing"), do: "badge-warning"
  defp status_color("resolved"), do: "badge-success"
  defp status_color("dismissed"), do: "badge-ghost"
  defp status_color(_), do: ""
end
