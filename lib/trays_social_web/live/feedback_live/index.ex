defmodule TraysSocialWeb.FeedbackLive.Index do
  @moduledoc """
  W262: Report a problem, at `/feedback`. The web twin of the iOS
  FeedbackView: a signed-in user picks Bug or Feedback, writes a message
  with an optional subject, and sends it.

  Signed-in users only, confirmed or not (an unconfirmed user is the one most
  likely to need help), so the route sits beside `/users/settings` outside
  the `:require_confirmed_user` scope. Signed-out visitors are sent to log
  in by `UserAuth`; the log-in page shows the support address instead.

  A report is stored through `TraysSocial.Feedback.submit/2` with platform
  `web`, the browser's user agent (`get_connect_info/2`, capped) and the
  optional `?from=` path as `screen`. `?from` is only stored, never used to
  redirect. Each send is counted against the per-user and per-address
  buckets in `TraysSocialWeb.FeedbackRateLimit`, shared with
  `POST /api/v1/feedback`, before it is validated, as the API does.

  Every outcome is an in-place state rather than a flash, and a refused
  send keeps what the user typed.
  """

  use TraysSocialWeb, :live_view

  alias TraysSocial.Feedback
  alias TraysSocial.Feedback.Submission
  alias TraysSocialWeb.FeedbackClientContext
  alias TraysSocialWeb.FeedbackRateLimit

  on_mount {TraysSocialWeb.UserAuth, :require_authenticated_user}
  on_mount {TraysSocialWeb.NotificationsHook, :mount_notifications}

  @kind_options [{"Bug", "bug"}, {"Feedback", "feedback"}]

  @impl true
  def mount(params, session, socket) do
    kind = if params["kind"] in Submission.kinds(), do: params["kind"], else: "bug"

    user_agent =
      if connected?(socket),
        do: socket |> get_connect_info(:user_agent) |> FeedbackClientContext.user_agent()

    socket =
      socket
      |> assign(:page_title, "Report a problem")
      |> assign(:current_tab, :settings)
      |> assign(:kind_options, @kind_options)
      |> assign(:body_max_length, Submission.body_max_length())
      |> assign(:from, FeedbackClientContext.from_path(params["from"]))
      |> assign(:user_agent, user_agent)
      |> assign(:ip_key, session["feedback_ip_key"])
      |> assign(:sent?, false)
      |> assign(:rate_limited?, false)
      |> assign_form(%{"kind" => kind}, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"feedback" => params}, socket) do
    {:noreply, assign_form(socket, params, :validate)}
  end

  def handle_event("send", %{"feedback" => params}, socket) do
    user = socket.assigns.current_scope.user

    with :ok <- FeedbackRateLimit.check_submission(user.id),
         :ok <- check_address(socket.assigns.ip_key),
         {:ok, _submission} <- Feedback.submit(user, submission_attrs(socket, params)) do
      {:noreply,
       socket
       |> assign(sent?: true, rate_limited?: false)
       |> assign_form(%{"kind" => params["kind"]}, nil)}
    else
      :rate_limited ->
        {:noreply, socket |> assign(:rate_limited?, true) |> assign_form(params, :insert)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:rate_limited?, false)
         |> assign(:form, to_form(changeset, as: :feedback))
         |> assign(:body_length, body_length(params))}
    end
  end

  def handle_event("send_another", _params, socket) do
    kind = socket.assigns.form[:kind].value || "bug"
    {:noreply, socket |> assign(:sent?, false) |> assign_form(%{"kind" => kind}, nil)}
  end

  # A bare form (no live_session callback, e.g. live_isolated) has no
  # address key; the per-user bucket still applies.
  defp check_address(nil), do: :ok
  defp check_address(ip_key), do: FeedbackRateLimit.check_address(ip_key)

  defp assign_form(socket, params, action) do
    changeset =
      %Submission{user_id: socket.assigns.current_scope.user.id}
      |> Submission.submit_changeset(submission_attrs(socket, params))

    changeset = if action, do: Map.put(changeset, :action, action), else: changeset

    socket
    |> assign(:form, to_form(changeset, as: :feedback))
    |> assign(:body_length, body_length(params))
  end

  # Only kind, subject and body come from the form. platform, user_agent
  # and screen are set here so the client cannot spoof them, and the owner
  # comes from the session scope inside Feedback.submit/2 (D44/D52).
  defp submission_attrs(socket, params) do
    params
    |> Map.take(["kind", "subject", "body"])
    |> Map.merge(%{
      "platform" => "web",
      "user_agent" => socket.assigns.user_agent,
      "screen" => socket.assigns.from
    })
  end

  # Graphemes after trimming, the same count Submission validates.
  defp body_length(%{"body" => body}) when is_binary(body),
    do: body |> String.trim() |> String.length()

  defp body_length(_params), do: 0

  defp field_errors(%Phoenix.HTML.FormField{} = field) do
    if Phoenix.Component.used_input?(field),
      do: Enum.map(field.errors, &TraysSocialWeb.CoreComponents.translate_error/1),
      else: []
  end

  defp format_count(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end
end
