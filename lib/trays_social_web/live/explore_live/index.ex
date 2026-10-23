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
  on_mount {TraysSocialWeb.UserAuth, :require_confirmed_user}
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

  # One search box (W205). Pressing Enter turns the typed text into an
  # ingredient chip; one term (chip or typed text) runs the normal search, two
  # or more switch to ingredient matching. Ingredient chips and recently used
  # chips live under ingredient_* names because :chips (filter chips above)
  # and :recent (the "New on Trays" rail) are already taken.
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
       |> assign_classic_rails()
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
    |> assign(:search_route, :idle)
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

  # The recipe-first branch of the template never renders the classic
  # trending / new / tag rails, so skip their queries there. The assigns are
  # still set because the classic branch of the template reads them.
  defp assign_classic_rails(%{assigns: %{recipe_first: true}} = socket) do
    assign(socket, trending: [], recent: [], tag_sections: [])
  end

  defp assign_classic_rails(socket) do
    assign(socket,
      trending: Posts.list_trending_posts(10),
      recent: Posts.list_recent_posts(10),
      tag_sections: load_tag_sections()
    )
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
     |> refresh()}
  end

  # Enter in the search box: the typed text becomes an ingredient chip.
  def handle_event("submit-search", %{"query" => q}, socket) do
    case add_chip(socket, q) do
      {:ok, socket} -> {:noreply, socket |> assign(:query, "") |> refresh()}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("submit-search", _params, socket), do: {:noreply, socket}

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
     |> refresh()}
  end

  def handle_event("clear-search", _params, socket) do
    {:noreply,
     socket
     |> assign(:query, "")
     |> assign(:active_chips, MapSet.new())
     |> assign(:ingredient_chips, [])
     |> assign(category: nil)
     |> refresh()}
  end

  # Browse tile (recipe_first only). The key is only ever looked up in the
  # fixed BrowseCategories list; an unknown or missing key is ignored.
  def handle_event("select-category", %{"key" => key}, %{assigns: %{recipe_first: true}} = socket) do
    case BrowseCategories.fetch(key) do
      nil ->
        {:noreply, socket}

      category ->
        {:noreply,
         socket
         |> assign(category: category.key, query: "", ingredient_chips: [])
         |> refresh()}
    end
  end

  def handle_event("select-category", _params, socket), do: {:noreply, socket}

  # "Recently used" chips add a chip directly, without touching the box.
  def handle_event("add-ingredient", %{"ingredient" => raw}, socket) do
    case add_chip(socket, raw) do
      {:ok, socket} -> {:noreply, refresh(socket)}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("add-ingredient", _params, socket), do: {:noreply, socket}

  def handle_event("remove-ingredient", %{"ingredient" => chip}, socket) when is_binary(chip) do
    chips = List.delete(socket.assigns.ingredient_chips, chip)

    {:noreply,
     socket
     |> assign(:ingredient_chips, chips)
     |> refresh()}
  end

  def handle_event("remove-ingredient", _params, socket), do: {:noreply, socket}

  # Sent by the SearchPrefs hook on mount and on every rejoin with whatever
  # localStorage held. Client-controlled: recent chips pass the same
  # validation as a typed chip. It never touches the current chips.
  def handle_event("restore-search-prefs", params, socket) do
    recent = sanitize_recent(params["recent"])

    {:noreply, assign(socket, recent_ingredients: recent, prefs_restored: true)}
  end

  # Adds a valid, new chip while there is room and records it as recently
  # used. Adding a chip replaces any selected Browse tile.
  defp add_chip(socket, raw) do
    chips = socket.assigns.ingredient_chips

    with {:ok, chip} <- clean_chip(raw),
         true <- length(chips) < @max_ingredient_chips,
         false <- chip in chips do
      recent =
        [chip | socket.assigns.recent_ingredients]
        |> Enum.uniq()
        |> Enum.take(@max_recent_ingredients)

      {:ok,
       socket
       |> assign(ingredient_chips: chips ++ [chip], recent_ingredients: recent, category: nil)
       |> push_prefs()}
    else
      _ -> :error
    end
  end

  defp clear_category_if_typed(socket, ""), do: socket
  defp clear_category_if_typed(socket, _q), do: assign(socket, :category, nil)

  defp refresh(socket) do
    route = search_route(socket.assigns.ingredient_chips, socket.assigns.query)
    socket = assign(socket, :search_route, route)

    case route do
      {:ingredients, terms} ->
        socket |> assign(groups: nil, results: []) |> refresh_ingredient_results(terms)

      {:term, term} ->
        socket |> assign(:ingredient_results, nil) |> refresh_results(term)

      :idle ->
        socket |> assign(:ingredient_results, nil) |> refresh_results("")
    end
  end

  # The search terms are the chips plus the typed text, unless the text
  # repeats a chip or the chip row is already full. No terms leaves the page
  # idle (Browse), one term searches normally, and two or more match recipes
  # by ingredient.
  defp search_route(chips, query) do
    typed = String.trim(query)

    terms =
      if typed == "" or String.downcase(typed) in chips or
           length(chips) >= @max_ingredient_chips,
         do: chips,
         else: chips ++ [typed]

    case terms do
      [] -> :idle
      [term] -> {:term, term}
      terms -> {:ingredients, terms}
    end
  end

  # Recipe-first: grouped search (tray / following / everyone) driven by the
  # search term or the selected Browse tile; nil groups shows Browse.
  defp refresh_results(%{assigns: %{recipe_first: true}} = socket, query) do
    category = BrowseCategories.fetch(socket.assigns.category)

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

  defp refresh_results(socket, query) do
    chips = socket.assigns.active_chips

    if query == "" and MapSet.size(chips) == 0 do
      assign(socket, :results, [])
    else
      user = socket.assigns.current_scope.user

      opts =
        [blocked_user_ids: Accounts.blocked_pair_ids(user.id)]
        |> maybe_put(:max_cooking_time, if(MapSet.member?(chips, :quick), do: 30))

      assign(socket, :results, Posts.search_posts(query, opts))
    end
  end

  defp search_term("", nil), do: ""
  defp search_term("", category), do: category.q || ""
  defp search_term(query, _category), do: query

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp refresh_ingredient_results(socket, terms) do
    user = socket.assigns.current_scope.user

    case IngredientSearch.normalize_terms(terms) do
      {:ok, terms} ->
        results =
          Posts.search_by_ingredients(user.id, terms,
            blocked_user_ids: Accounts.blocked_pair_ids(user.id),
            following_ids: Accounts.list_following_ids(user.id)
          )

        assign(socket, :ingredient_results, results)

      {:error, :invalid_ingredients} ->
        assign(socket, :ingredient_results, nil)
    end
  end

  # Until the hook has sent what it stored, this socket's prefs are defaults
  # (fresh mount or rejoin), and pushing them would overwrite the stored ones.
  defp push_prefs(%{assigns: %{prefs_restored: false}} = socket), do: socket

  defp push_prefs(socket) do
    push_event(socket, "search-prefs", %{recent: socket.assigns.recent_ingredients})
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
