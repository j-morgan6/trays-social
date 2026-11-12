defmodule TraysSocialWeb.ExploreLive.RecipeFirstComponents do
  @moduledoc """
  Recipe-first Search page (/search), restyled to the redesign canvas (W244,
  Main artboard Search states a and b): Browse tiles, Most saved, and grouped
  results (Cooks / In your tray / From people you follow / Everyone).

  Grids are uniform 4:3 rather than the canvas masonry, so cards in a row are
  the same size (the user's rule, as on iOS W243). Sponsored cards sit in
  Most saved and Everyone only, about one per 8 recipes, when web ads are on.
  """
  use TraysSocialWeb, :html

  alias TraysSocial.Monetization
  alias TraysSocialWeb.AdComponents
  alias TraysSocialWeb.API.V1.JSON.FeedItemJSON
  alias TraysSocialWeb.ExploreLive.Index
  alias TraysSocialWeb.HomeFormatting
  alias TraysSocialWeb.SearchFormatting

  @tile_fills %{cream: "bg-cream-lift", amber: "bg-accent/25", mint: "bg-mint-tint"}
  @section "mt-[30px] min-w-0 first:mt-0 md:mt-[42px]"

  attr :categories, :list, required: true
  attr :most_saved, :list, required: true
  attr :loading, :boolean, default: false
  attr :show_ads, :boolean, default: false

  def browse(assigns) do
    assigns =
      assigns
      |> assign(:tiles, Enum.with_index(assigns.categories))
      |> assign(:section, @section)

    ~H"""
    <section id="search-browse" class={@section}>
      <.section_heading title="Browse" />
      <div class="grid grid-cols-2 gap-2.5 md:grid-cols-3 md:gap-4">
        <.category_tile :for={{category, index} <- @tiles} category={category} index={index} />
      </div>
    </section>
    <section :if={@loading} id="search-loading" class={@section}>
      <.section_heading title="Most saved this week" />
      <div class="grid grid-cols-2 gap-3 md:grid-cols-4 md:gap-5">
        <.skeleton_card :for={_ <- 1..4} />
      </div>
    </section>
    <section :if={!@loading and @most_saved != []} id="search-most-saved" class={@section}>
      <.section_heading title="Most saved this week" />
      <.recipe_grid
        posts={@most_saved}
        ranks={SearchFormatting.ranks(@most_saved)}
        show_ads={@show_ads}
      />
    </section>
    """
  end

  attr :category, :map, required: true
  attr :index, :integer, required: true

  defp category_tile(assigns) do
    fill = SearchFormatting.tile_fill(assigns.index)
    assigns = assign(assigns, :fill, Map.fetch!(@tile_fills, fill))

    ~H"""
    <button
      type="button"
      phx-click="select-category"
      phx-value-key={@category.key}
      class={[
        "relative h-24 overflow-hidden rounded-[20px] p-3.5 text-left md:h-[120px] md:p-[18px] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary",
        @fill
      ]}
    >
      <span class="relative z-10 block max-w-[60%] font-display text-base font-bold leading-tight text-base-content md:text-lg">
        {@category.label}
      </span>
      <%!-- Placeholder photo slot: there are no category images yet. --%>
      <span
        aria-hidden="true"
        class="absolute -bottom-2.5 -right-2.5 size-[76px] -rotate-8 rounded-[18px] bg-base-100/70 shadow-card md:size-[98px]"
      >
      </span>
    </button>
    """
  end

  attr :groups, :map, required: true
  attr :show_ads, :boolean, default: false

  def grouped_results(assigns) do
    groups = assigns.groups

    assigns =
      assigns
      |> assign(:users, Map.get(groups, :users, []))
      |> assign(:paired?, groups.tray != [] or groups.following != [])
      |> assign(:section, @section)
      |> assign(:empty?, Enum.all?([groups.tray, groups.following, groups.everyone], &(&1 == [])))

    ~H"""
    <div :if={@empty? and @users == []} class="pt-6">
      <.empty_block
        chrome={:plain}
        title="No results yet."
        message="Try a different recipe, ingredient, or cook."
      />
    </div>
    <.cooks_panel users={@users} section={@section} />
    <div :if={@paired?} class={["grid gap-x-8 md:grid-cols-2", @section]}>
      <.row_group id="search-tray" title="In your tray" posts={@groups.tray} />
      <.row_group id="search-following" title="From people you follow" posts={@groups.following} />
    </div>
    <section :if={@groups.everyone != []} id="search-everyone" class={@section}>
      <.section_heading title="Everyone" />
      <.recipe_grid posts={@groups.everyone} ranks={%{}} show_ads={@show_ads} />
    </section>
    """
  end

  @doc """
  Search state e (canvas "Loading, term" / "Loading, ingredients"): the
  shape of the current results (it can differ from the next ones). It is hidden until LiveView
  puts phx-change-loading or phx-submit-loading on `#search-form` (the
  `search-loading` variant in app.css), and it holds no links, so the nav
  link counts in the dead render stay exact.
  """
  attr :ingredients, :boolean, default: false

  def results_skeleton(assigns) do
    assigns = assign(assigns, :pulse, "bg-base-300 animate-pulse motion-reduce:animate-none")

    ~H"""
    <div
      id="search-results-loading"
      aria-hidden="true"
      class="hidden search-loading:block"
    >
      <div :if={@ingredients} id="search-results-loading-ingredients">
        <div class={["mt-6 h-[84px] rounded-[22px]", @pulse]}></div>
        <div class={["mt-[30px] mb-4 h-4 w-40 rounded-md", @pulse]}></div>
        <div class="flex flex-col gap-2.5">
          <.skeleton_row :for={_ <- 1..3} />
        </div>
      </div>
      <div :if={!@ingredients} id="search-results-loading-term">
        <div class={["mb-4 h-4 w-[70px] rounded-md", @pulse]}></div>
        <div class="rounded-[22px] bg-base-100 px-4 shadow-card">
          <div :for={_ <- 1..2} class="flex min-h-[60px] items-center gap-3 py-2">
            <div class={["size-12 shrink-0 rounded-full", @pulse]}></div>
            <div class={["h-4 w-[100px] rounded-md", @pulse]}></div>
          </div>
        </div>
        <div class={["mt-[30px] mb-4 h-4 w-[110px] rounded-md", @pulse]}></div>
        <div class="flex flex-col gap-2.5">
          <.skeleton_row :for={_ <- 1..3} />
        </div>
        <div class={["mt-[30px] mb-4 h-4 w-[90px] rounded-md", @pulse]}></div>
        <div class="grid grid-cols-2 gap-3 md:grid-cols-4 md:gap-5">
          <.skeleton_card :for={_ <- 1..4} />
        </div>
      </div>
    </div>
    """
  end

  attr :users, :list, required: true
  attr :section, :string, required: true

  defp cooks_panel(assigns) do
    ~H"""
    <section :if={@users != []} id="search-cooks" class={@section}>
      <.section_heading title="Cooks" />
      <div class="rounded-[22px] bg-base-100 px-4 shadow-card">
        <div class="grid divide-y divide-hairline md:grid-cols-3 md:gap-x-8 md:divide-y-0">
          <.link
            :for={user <- @users}
            navigate={~p"/@#{user.username}"}
            class="flex min-h-[60px] min-w-0 items-center gap-3 py-2 text-base-content hover:text-primary-ink"
          >
            <.user_avatar
              username={user.username}
              photo_url={user.profile_photo_url}
              size="lg"
              class="shrink-0"
            />
            <span class="min-w-0 flex-1 truncate text-[15px] font-semibold">@{user.username}</span>
            <.icon name="hero-chevron-right" class="size-4 shrink-0 text-muted" />
          </.link>
        </div>
      </div>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :posts, :list, required: true

  defp row_group(assigns) do
    ~H"""
    <section :if={@posts != []} id={@id} class="mt-[30px] min-w-0 first:mt-0 md:mt-0">
      <.section_heading title={@title} />
      <div class="flex flex-col gap-2.5">
        <.row_card
          :for={post <- @posts}
          navigate={~p"/posts/#{post.id}"}
          title={Index.post_title(post)}
          photo_url={post.photo_url}
          author_name={post.user.username}
          author_avatar_url={post.user.profile_photo_url}
          detail={HomeFormatting.cook_time_label(post.cooking_time_minutes)}
        />
      </div>
    </section>
    """
  end

  attr :posts, :list, required: true
  attr :ranks, :map, required: true
  attr :show_ads, :boolean, required: true

  defp recipe_grid(assigns) do
    assigns = assign(assigns, :items, grid_items(assigns.posts, assigns.show_ads))

    ~H"""
    <div class="grid grid-cols-2 gap-3 md:grid-cols-4 md:gap-5">
      <%= for item <- @items do %>
        <AdComponents.sponsored_card :if={item.type == "ad"} slot={item.ad.slot} />
        <.recipe_card
          :if={item.type == "post"}
          navigate={~p"/posts/#{item.post.id}"}
          title={Index.post_title(item.post)}
          photo_url={item.post.photo_url}
          aspect="4:3"
          cook_time={HomeFormatting.cook_time_label(item.post.cooking_time_minutes)}
          badge={rank_badge(@ranks, item.post.id)}
          author_name={item.post.user.username}
          author_avatar_url={item.post.user.profile_photo_url}
          class="min-w-0"
        />
      <% end %>
    </div>
    """
  end

  # Posts wrapped as grid items; with ads on, a sponsored item follows every
  # full run of Monetization.ad_frequency() posts (never trailing), the same
  # density rule the API uses for the iOS Find grids.
  defp grid_items(posts, false), do: Enum.map(posts, &%{type: "post", post: &1})

  defp grid_items(posts, true) do
    posts
    |> grid_items(false)
    |> FeedItemJSON.interleave_ads(Monetization.ad_frequency(), "find")
  end

  defp rank_badge(ranks, post_id) do
    case Map.fetch(ranks, post_id) do
      {:ok, rank} -> {:rank, rank}
      :error -> nil
    end
  end
end
