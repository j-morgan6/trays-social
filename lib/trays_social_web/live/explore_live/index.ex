defmodule TraysSocialWeb.ExploreLive.Index do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Posts

  on_mount {TraysSocialWeb.UserAuth, :require_authenticated_user}
  on_mount {TraysSocialWeb.NotificationsHook, :mount_notifications}

  # Filter chips for the editorial Find screen. Only :quick is wired to
  # the search backend today (max_cooking_time=30); the rest toggle state
  # so the UI feels responsive and the wiring lives in one place when
  # the tags/joins are added.
  @chips [
    %{id: :quick, label: "Under 30 min", icon: "hero-clock"},
    %{id: :vegetarian, label: "Vegetarian", icon: "hero-sparkles"},
    %{id: :one_pan, label: "One pan", icon: "hero-square-3-stack-3d"},
    %{id: :has_video, label: "Has video", icon: "hero-video-camera"},
    %{id: :following, label: "By cooks I follow", icon: "hero-user-group"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      {:ok,
       socket
       |> assign_static()
       |> assign(:loading, false)
       |> assign(:trending, Posts.list_trending_posts(10))
       |> assign(:recent, Posts.list_recent_posts(10))
       |> assign(:tag_sections, load_tag_sections())
       |> assign(:results, [])}
    else
      {:ok,
       socket
       |> assign_static()
       |> assign(:loading, true)
       |> assign(:trending, [])
       |> assign(:recent, [])
       |> assign(:tag_sections, [])
       |> assign(:results, [])}
    end
  end

  defp assign_static(socket) do
    socket
    |> assign(:page_title, "Find")
    |> assign(:current_tab, :explore)
    |> assign(:query, "")
    |> assign(:active_chips, MapSet.new())
    |> assign(:chips, @chips)
  end

  defp load_tag_sections do
    tags = Posts.list_top_tags(6)
    Posts.list_posts_by_tags(tags, 8)
  end

  @impl true
  def handle_event("search", %{"query" => q}, socket) do
    {:noreply,
     socket
     |> assign(:query, q)
     |> refresh_results()}
  end

  def handle_event("toggle-chip", %{"id" => id}, socket) do
    id_atom = String.to_existing_atom(id)
    active = socket.assigns.active_chips

    new_active =
      if MapSet.member?(active, id_atom),
        do: MapSet.delete(active, id_atom),
        else: MapSet.put(active, id_atom)

    {:noreply,
     socket
     |> assign(:active_chips, new_active)
     |> refresh_results()}
  end

  def handle_event("clear-search", _params, socket) do
    {:noreply,
     socket
     |> assign(:query, "")
     |> assign(:active_chips, MapSet.new())
     |> assign(:results, [])}
  end

  defp refresh_results(socket) do
    query = socket.assigns.query
    chips = socket.assigns.active_chips

    if query == "" and MapSet.size(chips) == 0 do
      assign(socket, :results, [])
    else
      opts =
        []
        |> maybe_put(:max_cooking_time, if(MapSet.member?(chips, :quick), do: 30))

      assign(socket, :results, Posts.search_posts(query, opts))
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  # Derive a serif title from a post's caption, matching the convention
  # used on Feed and Recipe Detail.
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
