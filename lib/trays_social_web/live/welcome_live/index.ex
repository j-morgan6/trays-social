defmodule TraysSocialWeb.WelcomeLive.Index do
  @moduledoc """
  First-run welcome — introduces the three trays (Feed / Find / My Tray)
  to a new cook before they hit the Feed.

  Shown once: FeedLive.Index redirects unfinished users here, the "Got
  it" CTA stamps `seen_welcome_at` and pushes them back to /.
  """
  use TraysSocialWeb, :live_view

  alias TraysSocial.Accounts

  on_mount {TraysSocialWeb.UserAuth, :require_authenticated_user}
  on_mount {TraysSocialWeb.NotificationsHook, :mount_notifications}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    # If the cook has already seen the welcome, don't show it again —
    # bounce them to the feed.
    if user.seen_welcome_at do
      {:ok, push_navigate(socket, to: ~p"/")}
    else
      {:ok,
       socket
       |> assign(:page_title, "Welcome to Trays")
       |> assign(:current_tab, :feed)
       |> assign(:user, user)}
    end
  end

  @impl true
  def handle_event("continue", _params, socket) do
    user = socket.assigns.user

    case Accounts.mark_welcome_seen(user) do
      {:ok, _updated} ->
        {:noreply, push_navigate(socket, to: ~p"/")}

      {:error, _changeset} ->
        # Even if the stamp fails, don't block the cook — they can re-see
        # the welcome and try again.
        {:noreply, push_navigate(socket, to: ~p"/")}
    end
  end
end
