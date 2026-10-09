defmodule TraysSocialWeb.ExploreLive.Index do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Accounts
  alias TraysSocial.Features
  alias TraysSocial.Posts
  alias TraysSocial.Posts.BrowseCategories
  alias TraysSocial.Posts.IngredientSearch
  alias TraysSocialWeb.ExploreLive.IngredientComponents
  alias TraysSocialWeb.ExploreLive.RecipeFirstComponents

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

  # "What I have" mode. Ingredient chips and recently used chips live under
  # ingredient_* names because :chips (filter chips above) and :recent (the
  # "New on Trays" rail) are already taken.
  @modes ~w(recipes have)
  @max_ingredient_chips 10
  @max_recent_ingredients 10

  # With recipe_first on, /explore is retired in favour of /search (same
  # LiveView, :search action).
  @impl true
  def mount(_params, _session, socket) do
    if Features.recipe_first?() and socket.assigns.live_action == :index do
      {:ok, push_navigate(socket, to: ~p"/search")}
    else
      mount_page(socket)
    end
  end

  defp mount_page(socket) do
    if connected?(socket) do
      {:ok,
       socket
       |> assign_static()
       |> assign(:loading, false)
       |> assign(:trending, Posts.list_trending_posts(10))
       |> assign(:recent, Posts.list_recent_posts(10))
       |> assign(:tag_sections, load_tag_sections())
       |> assign(:results, [])
       |> maybe_assign_most_saved()}
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
    recipe_first = Features.recipe_first?()

    socket
    |> assign(:page_title, if(recipe_first, do: "Search", else: "Find"))
    |> assign(:current_tab, :explore)
    |> assign(:query, "")
    |> assign(:active_chips, MapSet.new())
    |> assign(:chips, @chips)
    |> assign(:mode, "recipes")
    |> assign(:ingredient_chips, [])
    |> assign(:recent_ingredients, [])
    |> assign(:ingredient_results, nil)
    |> assign(:max_ingredient_chips, @max_ingredient_chips)
    |> assign(:prefs_restored, false)
    |> assign(:recipe_first, recipe_first)
    |> assign(:categories, BrowseCategories.list())
    |> assign(:category, nil)
    |> assign(:groups, nil)
    |> assign(:most_saved, [])
  end

  defp maybe_assign_most_saved(%{assigns: %{recipe_first: true}} = socket) do
    user = socket.assigns.current_scope.user

    assign(
      socket,
      :most_saved,
      Posts.list_most_saved_posts(10, blocked_user_ids: Accounts.blocked_pair_ids(user.id))
    )
  end

  defp maybe_assign_most_saved(socket), do: socket

  defp load_tag_sections do
    tags = Posts.list_top_tags(6)
    Posts.list_posts_by_tags(tags, 8)
  end

  @impl true
  def handle_event("search", %{"query" => q}, socket) do
    {:noreply,
     socket
     |> assign(:query, q)
     |> clear_category_if_typed(q)
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
     |> assign(:results, [])
     |> assign(category: nil, groups: nil)}
  end

  # Browse tile (recipe_first only). The key is only ever looked up in the
  # fixed BrowseCategories list; an unknown or missing key is ignored.
  def handle_event("select-category", %{"key" => key}, %{assigns: %{recipe_first: true}} = socket) do
    case BrowseCategories.fetch(key) do
      nil ->
        {:noreply, socket}

      category ->
        {:noreply, socket |> assign(category: category.key, query: "") |> refresh_results()}
    end
  end

  def handle_event("select-category", _params, socket), do: {:noreply, socket}

  def handle_event("set-mode", %{"mode" => mode}, socket) when mode in @modes do
    {:noreply, socket |> assign(:mode, mode) |> push_prefs()}
  end

  def handle_event("set-mode", _params, socket), do: {:noreply, socket}

  def handle_event("add-ingredient", %{"ingredient" => raw}, socket) do
    chips = socket.assigns.ingredient_chips

    case clean_chip(raw) do
      {:ok, chip} when length(chips) < @max_ingredient_chips ->
        if chip in chips do
          {:noreply, socket}
        else
          {:noreply,
           socket
           |> assign(:ingredient_chips, chips ++ [chip])
           |> refresh_ingredient_results()}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("add-ingredient", _params, socket), do: {:noreply, socket}

  def handle_event("remove-ingredient", %{"ingredient" => chip}, socket) when is_binary(chip) do
    chips = List.delete(socket.assigns.ingredient_chips, chip)

    {:noreply,
     socket
     |> assign(:ingredient_chips, chips)
     |> refresh_ingredient_results()}
  end

  def handle_event("remove-ingredient", _params, socket), do: {:noreply, socket}

  # Sent by the SearchPrefs hook on mount and on every rejoin with whatever
  # localStorage held. Client-controlled: the mode is whitelisted and recent
  # chips pass the same validation as a typed chip. It never touches the
  # current chips.
  def handle_event("restore-search-prefs", params, socket) do
    mode = if params["mode"] in @modes, do: params["mode"], else: "recipes"
    recent = sanitize_recent(params["recent"])

    {:noreply, assign(socket, mode: mode, recent_ingredients: recent, prefs_restored: true)}
  end

  defp clear_category_if_typed(socket, ""), do: socket
  defp clear_category_if_typed(socket, _q), do: assign(socket, :category, nil)

  # Recipe-first: grouped search (tray / following / everyone) driven by the
  # typed query or the selected Browse tile; nil groups shows Browse.
  defp refresh_results(%{assigns: %{recipe_first: true}} = socket) do
    category = BrowseCategories.fetch(socket.assigns.category)
    query = socket.assigns.query

    if query == "" and is_nil(category) do
      assign(socket, :groups, nil)
    else
      user = socket.assigns.current_scope.user

      groups =
        Posts.search_grouped(user.id, search_term(query, category),
          following_ids: Accounts.list_following_ids(user.id),
          blocked_user_ids: Accounts.blocked_pair_ids(user.id),
          max_cooking_time: category && category.max_cooking_time,
          tag: category && category.tag
        )

      assign(socket, :groups, groups)
    end
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

  defp search_term("", nil), do: ""
  defp search_term("", category), do: category.q || ""
  defp search_term(query, _category), do: query

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp refresh_ingredient_results(%{assigns: %{ingredient_chips: []}} = socket) do
    assign(socket, :ingredient_results, nil)
  end

  defp refresh_ingredient_results(socket) do
    user = socket.assigns.current_scope.user

    case IngredientSearch.normalize_terms(socket.assigns.ingredient_chips) do
      {:ok, terms} ->
        results =
          Posts.search_by_ingredients(user.id, terms,
            blocked_user_ids: Accounts.blocked_pair_ids(user.id),
            following_ids: Accounts.list_following_ids(user.id)
          )

        recent =
          (socket.assigns.ingredient_chips ++ socket.assigns.recent_ingredients)
          |> Enum.uniq()
          |> Enum.take(@max_recent_ingredients)

        socket
        |> assign(ingredient_results: results, recent_ingredients: recent)
        |> push_prefs()

      {:error, :invalid_ingredients} ->
        assign(socket, :ingredient_results, nil)
    end
  end

  # Until the hook has sent what it stored, this socket's prefs are defaults
  # (fresh mount or rejoin), and pushing them would overwrite the stored ones.
  defp push_prefs(%{assigns: %{prefs_restored: false}} = socket), do: socket

  defp push_prefs(socket) do
    push_event(socket, "search-prefs", %{
      mode: socket.assigns.mode,
      recent: socket.assigns.recent_ingredients
    })
  end

  # A chip is kept as typed (trimmed, lowercased) but must pass the same rules
  # the search applies, so an over-long or control-character chip is refused
  # up front instead of being shown and then silently failing the search.
  defp clean_chip(raw) when is_binary(raw) do
    with true <- String.valid?(raw),
         chip = raw |> String.trim() |> String.downcase(),
         true <- chip != "",
         {:ok, _terms} <- IngredientSearch.normalize_terms([chip]) do
      {:ok, chip}
    else
      _ -> :error
    end
  end

  defp clean_chip(_raw), do: :error

  defp sanitize_recent(list) when is_list(list) do
    list
    |> Enum.take(50)
    |> Enum.flat_map(fn item ->
      case clean_chip(item) do
        {:ok, chip} -> [chip]
        :error -> []
      end
    end)
    |> Enum.uniq()
    |> Enum.take(@max_recent_ingredients)
  end

  defp sanitize_recent(_other), do: []

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
