defmodule TraysSocialWeb.ExploreLive.IngredientComponents do
  @moduledoc """
  "What I have" panel for the Find page: chip input, grouped results with
  missing ingredients, and recently used chips.
  """
  use TraysSocialWeb, :html

  alias TraysSocialWeb.ExploreLive.Index

  attr :chips, :list, required: true
  attr :recent, :list, required: true
  attr :results, :map, default: nil
  attr :max_chips, :integer, default: 10

  def ingredient_panel(assigns) do
    assigns = assign(assigns, :suggestions, Enum.reject(assigns.recent, &(&1 in assigns.chips)))

    ~H"""
    <div class="space-y-5">
      <.form for={%{}} as={:ingredient} id="ingredient-form" phx-submit="add-ingredient">
        <input
          id={"ingredient-input-#{length(@chips)}"}
          type="text"
          name="ingredient"
          placeholder="Add an ingredient…"
          aria-label="Add an ingredient"
          autocomplete="off"
          maxlength="50"
          disabled={length(@chips) >= @max_chips}
          phx-mounted={@chips != [] && JS.focus()}
          class="w-full h-14 rounded-full bg-base-200 border border-base-300 px-5 text-[17px] text-base-content placeholder:text-base-content/40 outline-none focus:border-primary transition-colors"
        />
      </.form>

      <div :if={@chips != []} class="flex flex-wrap gap-2">
        <button
          :for={chip <- @chips}
          type="button"
          phx-click="remove-ingredient"
          phx-value-ingredient={chip}
          aria-label={"Remove #{chip}"}
          class="inline-flex items-center gap-1.5 h-8 px-3.5 rounded-full text-[13px] bg-primary text-primary-content border border-primary"
        >
          {chip}
          <.icon name="hero-x-mark" class="size-3 opacity-70 -mr-1" />
        </button>
      </div>

      <p :if={length(@chips) >= @max_chips} class="text-sm text-base-content/60">
        Up to {@max_chips} ingredients
      </p>

      <p :if={@chips == []} class="text-base-content/70">
        Add what's in your kitchen to see what you can make.
      </p>

      <%= if @results do %>
        <div
          :if={@results.everything == [] and @results.almost == []}
          class="bg-base-100 border border-base-300 rounded-sm p-10 text-center"
        >
          <p class="font-serif-editorial italic text-[17px] text-base-content/70">
            No matches yet. Try removing an ingredient.
          </p>
        </div>
        <.match_group title="You have everything" matches={@results.everything} />
        <.match_group title="Almost there" matches={@results.almost} />
      <% end %>

      <div :if={@suggestions != []}>
        <h3 class="text-xs font-bold uppercase tracking-wide text-base-content/60 mb-2">
          Recently used
        </h3>
        <div class="flex flex-wrap gap-2">
          <button
            :for={chip <- @suggestions}
            type="button"
            phx-click="add-ingredient"
            phx-value-ingredient={chip}
            aria-label={"Add #{chip}"}
            class="inline-flex items-center gap-1.5 h-8 px-3.5 rounded-full text-[13px] bg-base-100 text-base-content border border-base-300 hover:border-base-content/30"
          >
            <.icon name="hero-plus" class="size-3" />
            {chip}
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :matches, :list, required: true

  defp match_group(assigns) do
    ~H"""
    <section :if={@matches != []}>
      <h3 class="text-xs font-bold uppercase tracking-wide text-base-content/60 mb-2">{@title}</h3>
      <ul class="space-y-2">
        <li :for={match <- @matches}>
          <.link navigate={~p"/posts/#{match.post.id}"} class="flex items-center gap-3">
            <img
              src={TraysSocial.Uploads.ImageProcessor.thumb_url(match.post.photo_url)}
              alt=""
              class="h-14 w-14 rounded-lg object-cover bg-base-200"
            />
            <div class="min-w-0">
              <p class="font-semibold truncate">{Index.post_title(match.post)}</p>
              <p class="text-sm text-base-content/60">@{match.post.user.username}</p>
              <p :if={match.missing != []} class="text-sm text-base-content/60">
                missing: {Enum.join(match.missing, ", ")}
              </p>
            </div>
          </.link>
        </li>
      </ul>
    </section>
    """
  end
end
