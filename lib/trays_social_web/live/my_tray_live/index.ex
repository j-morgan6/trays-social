defmodule TraysSocialWeb.MyTrayLive.Index do
  @moduledoc """
  My Tray — a cook's saved recipes. The header's "My Tray" nav item
  lives here. Backed by the existing bookmark store: each saved post
  becomes a tray entry.

  User-defined collections (e.g. "To try", "Mainstays") are part of the
  editorial design but don't have a schema today. The collections row
  renders a single "All saved" collection plus a disabled
  "+ New collection" placeholder so the structure is in place when the
  schema lands.
  """
  use TraysSocialWeb, :live_view

  alias TraysSocial.Posts

  on_mount {TraysSocialWeb.UserAuth, :require_authenticated_user}
  on_mount {TraysSocialWeb.NotificationsHook, :mount_notifications}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    if connected?(socket) do
      bookmarks = Posts.list_bookmarks(user.id, limit: 40)

      {:ok,
       socket
       |> assign_static()
       |> assign(:loading, false)
       |> assign(:bookmarks, bookmarks)
       |> assign(:saved_count, length(bookmarks))}
    else
      {:ok,
       socket
       |> assign_static()
       |> assign(:loading, true)
       |> assign(:bookmarks, [])
       |> assign(:saved_count, 0)}
    end
  end

  defp assign_static(socket) do
    socket
    |> assign(:page_title, "My Tray")
    |> assign(:current_tab, :my_tray)
  end

  # Derive a serif-friendly recipe title from a post's caption, matching
  # the convention used on Feed, Recipe Detail, Notifications, Find.
  def post_title(%{caption: caption}) do
    case String.split(caption || "", ~r/[\n.!?]/, parts: 2, trim: true) do
      [t | _] ->
        case String.trim(t) do
          "" -> "Untitled recipe"
          title -> title
        end

      _ ->
        "Untitled recipe"
    end
  end
end
