defmodule TraysSocialWeb.ExploreLive.RecipeFirstComponents do
  @moduledoc """
  Recipe-first Search page (/search): Browse tiles, the Most saved rail, and
  grouped results (In your tray / From people you follow / Everyone).
  """
  use TraysSocialWeb, :html

  alias TraysSocial.Uploads.ImageProcessor
  alias TraysSocialWeb.ExploreLive.Index

  attr :categories, :list, required: true
  attr :most_saved, :list, required: true

  def browse(assigns) do
    ~H"""
    <section class="space-y-6">
      <div>
        <h2 class="text-xs font-bold uppercase tracking-wide text-base-content/60 mb-2">Browse</h2>
        <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
          <button
            :for={c <- @categories}
            type="button"
            phx-click="select-category"
            phx-value-key={c.key}
            class="h-20 rounded-xl bg-base-200 p-3 text-left font-bold flex items-end hover:bg-base-300 transition-colors"
          >
            {c.label}
          </button>
        </div>
      </div>
      <div :if={@most_saved != []}>
        <h2 class="text-xs font-bold uppercase tracking-wide text-base-content/60 mb-2">
          Most saved this week
        </h2>
        <.recipe_grid posts={@most_saved} />
      </div>
    </section>
    """
  end

  attr :groups, :map, required: true

  def grouped_results(assigns) do
    ~H"""
    <div class="space-y-8">
      <.group title="In your tray" posts={@groups.tray} />
      <.group title="From people you follow" posts={@groups.following} />
      <.group title="Everyone" posts={@groups.everyone} />
      <p
        :if={@groups.tray == [] and @groups.following == [] and @groups.everyone == []}
        class="text-base-content/70"
      >
        No results yet. Try a different recipe, ingredient, or cook.
      </p>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :posts, :list, required: true

  defp group(assigns) do
    ~H"""
    <section :if={@posts != []}>
      <h2 class="text-xs font-bold uppercase tracking-wide text-base-content/60 mb-2">{@title}</h2>
      <.recipe_grid posts={@posts} />
    </section>
    """
  end

  attr :posts, :list, required: true

  defp recipe_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
      <.link
        :for={post <- @posts}
        navigate={~p"/posts/#{post.id}"}
        class="block rounded-xl overflow-hidden bg-base-200"
      >
        <img
          src={ImageProcessor.thumb_url(post.photo_url)}
          alt=""
          class="aspect-[4/5] w-full object-cover"
        />
        <p class="p-2 text-sm font-semibold truncate">{Index.post_title(post)}</p>
      </.link>
    </div>
    """
  end
end
