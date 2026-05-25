defmodule TraysSocialWeb.Admin.ReportsLive do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.User
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
     |> assign(:target_users, load_target_users(reports))
     |> assign(:filter, "all")}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    reports =
      if status == "all",
        do: Reports.list_reports(),
        else: Reports.list_reports(status: status)

    {:noreply,
     socket
     |> assign(reports: reports, filter: status)
     |> assign(:target_users, load_target_users(reports))}
  end

  @impl true
  def handle_event("resolve", %{"id" => id, "status" => status}, socket) do
    report = Reports.get_report!(id)
    current_user = socket.assigns.current_scope.user

    {:ok, _} = Reports.resolve_report(report, %{status: status, resolved_by_id: current_user.id})

    {:noreply, reload_reports(socket)}
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

    {:noreply, reload_reports(socket)}
  end

  @impl true
  def handle_event("suspend_user", params, socket) do
    %{"report_id" => report_id} = params
    report = Reports.get_report!(report_id)
    current_user = socket.assigns.current_scope.user

    with :user_target <- target_kind(report),
         :not_self <- self_check(report, current_user),
         {:ok, suspended_until} <- parse_suspension_date(params["suspended_until"]),
         %User{} = target <- Accounts.get_user(report.target_id) do
      {:ok, _} = Accounts.suspend_user(target, suspended_until)

      {:ok, _} =
        Reports.resolve_report(report, %{
          status: "resolved",
          resolved_by_id: current_user.id
        })

      {:noreply,
       socket
       |> reload_reports()
       |> put_flash(:info, suspension_confirmation(suspended_until))}
    else
      :wrong_target ->
        {:noreply, put_flash(socket, :error, "Suspend only applies to user-typed reports.")}

      :self ->
        {:noreply, put_flash(socket, :error, "You cannot suspend yourself.")}

      :bad_date ->
        {:noreply,
         put_flash(socket, :error, "Couldn't parse that date — leave blank for indefinite.")}

      nil ->
        {:noreply, put_flash(socket, :error, "Target user no longer exists.")}
    end
  end

  @impl true
  def handle_event("unsuspend_user", %{"id" => report_id}, socket) do
    report = Reports.get_report!(report_id)

    if report.target_type == "user" do
      case Accounts.get_user(report.target_id) do
        %User{} = target ->
          {:ok, _} = Accounts.unsuspend_user(target)

          {:noreply,
           socket
           |> reload_reports()
           |> put_flash(:info, "Suspension lifted.")}

        nil ->
          {:noreply, put_flash(socket, :error, "Target user no longer exists.")}
      end
    else
      {:noreply, socket}
    end
  end

  defp target_kind(%{target_type: "user"}), do: :user_target
  defp target_kind(_), do: :wrong_target

  defp self_check(%{target_id: id}, %{id: id}), do: :self
  defp self_check(_, _), do: :not_self

  defp reload_reports(socket) do
    reports =
      if socket.assigns.filter == "all",
        do: Reports.list_reports(),
        else: Reports.list_reports(status: socket.assigns.filter)

    socket
    |> assign(:reports, reports)
    |> assign(:target_users, load_target_users(reports))
  end

  defp load_target_users(reports) do
    user_ids =
      reports
      |> Enum.filter(&(&1.target_type == "user"))
      |> Enum.map(& &1.target_id)
      |> Enum.uniq()

    user_ids
    |> Enum.map(&{&1, Accounts.get_user(&1)})
    |> Enum.reject(fn {_id, user} -> is_nil(user) end)
    |> Map.new()
  end

  # Returns {:ok, nil} for an intentional "indefinite" suspension (empty
  # input), {:ok, %DateTime{}} for a valid date, or :bad_date for malformed
  # input. The HTML `type="date"` prevents the latter in browsers, but we
  # surface it explicitly rather than silently suspending indefinitely on a
  # typo.
  defp parse_suspension_date(nil), do: {:ok, nil}
  defp parse_suspension_date(""), do: {:ok, nil}

  defp parse_suspension_date(date_str) when is_binary(date_str) do
    case Date.from_iso8601(date_str) do
      # Coerce to end-of-day UTC so "suspend until May 30" stays in force
      # through May 30 in the user's local timezone rather than expiring at
      # midnight UTC mid-business-day.
      {:ok, date} -> {:ok, DateTime.new!(date, ~T[23:59:59], "Etc/UTC")}
      _ -> :bad_date
    end
  end

  defp parse_suspension_date(_), do: :bad_date

  defp suspension_confirmation(nil), do: "User suspended indefinitely."

  defp suspension_confirmation(%DateTime{} = until) do
    "User suspended until #{Calendar.strftime(until, "%B %-d, %Y")}."
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

          <div :if={report.status == "open"} class="mt-3 flex gap-2 flex-wrap">
            <button :if={report.target_type == "post"} phx-click="remove_post" phx-value-id={report.id}
              class="btn btn-sm btn-error">Remove Post</button>
            <button phx-click="resolve" phx-value-id={report.id} phx-value-status="resolved"
              class="btn btn-sm btn-success">Resolve</button>
            <button phx-click="resolve" phx-value-id={report.id} phx-value-status="dismissed"
              class="btn btn-sm btn-ghost">Dismiss</button>
          </div>

          <div :if={report.target_type == "user"} class="mt-3 border-t pt-3">
            <%= case Map.get(@target_users, report.target_id) do %>
              <% nil -> %>
                <p class="text-xs text-base-content/60">Target user no longer exists.</p>
              <% %{} = target -> %>
                <%= if User.is_suspended?(target) do %>
                  <div class="flex items-center gap-3 text-sm">
                    <span>
                      <strong>@{target.username}</strong> suspended
                      {format_suspended_until(target.suspended_until)}.
                    </span>
                    <button phx-click="unsuspend_user" phx-value-id={report.id}
                      class="btn btn-xs btn-ghost">Lift suspension</button>
                  </div>
                <% else %>
                  <form phx-submit="suspend_user" class="flex items-center gap-2 flex-wrap text-sm">
                    <input type="hidden" name="report_id" value={report.id} />
                    <span>Suspend <strong>@{target.username}</strong> until</span>
                    <input type="date" name="suspended_until" class="input input-sm input-bordered" />
                    <button type="submit" class="btn btn-sm btn-warning">Suspend</button>
                    <span class="text-xs text-base-content/60">(leave blank for indefinite)</span>
                  </form>
                <% end %>
            <% end %>
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

  defp format_suspended_until(%DateTime{} = until) do
    if Accounts.indefinite_suspension?(until) do
      "indefinitely"
    else
      "until " <> Calendar.strftime(until, "%B %-d, %Y")
    end
  end

  defp format_suspended_until(_), do: ""
end
