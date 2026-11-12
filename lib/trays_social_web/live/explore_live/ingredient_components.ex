defmodule TraysSocialWeb.ExploreLive.IngredientComponents do
  @moduledoc """
  Ingredient pieces of the single search box on the Find / Search page:
  the chip row under the box, recently used chips, and the "You have
  everything" / "Almost there" results with the summary card (W244 restyle,
  Main artboard Search state c).
  """
  use TraysSocialWeb, :html

  alias TraysSocialWeb.ExploreLive.Index
  alias TraysSocialWeb.HomeFormatting
  alias TraysSocialWeb.SearchFormatting

  attr :chips, :list, required: true
  attr :recent, :list, required: true
  attr :typing, :boolean, default: false
  attr :max_chips, :integer, default: 10

  def chip_bar(assigns) do
    assigns =
      assign(assigns,
        suggestions: Enum.reject(assigns.recent, &(&1 in assigns.chips)),
        full: length(assigns.chips) >= assigns.max_chips
      )

    ~H"""
    <div :if={@chips != []} class="mt-3 flex flex-wrap gap-2">
      <.ingredient_chip
        :for={chip <- @chips}
        name={chip}
        phx-click="remove-ingredient"
        phx-value-ingredient={chip}
      />
    </div>

    <p :if={@full} class="mx-1 mt-2.5 text-[13px] text-muted">
      Up to {@max_chips} ingredients
    </p>

    <p
      :if={!@full and length(@chips) < 2 and (@typing or @chips != [])}
      class="mx-1 mt-2.5 text-[13px] text-muted"
    >
      Press Enter to add an ingredient. Add two or more to see what you can make.
    </p>

    <div :if={@suggestions != [] and not @typing and not @full} class="mt-[18px]">
      <h3 class="text-[15px] font-semibold leading-tight text-base-content">Recently used</h3>
      <div class="mt-2 flex flex-wrap gap-2">
        <.recent_chip
          :for={chip <- @suggestions}
          name={chip}
          class="max-w-full"
          phx-click="add-ingredient"
          phx-value-ingredient={chip}
        />
      </div>
    </div>
    """
  end

  attr :results, :map, default: nil
  attr :terms, :list, default: [], doc: "the searched ingredients (chips plus typed text)"

  def ingredient_results(assigns) do
    ~H"""
    <div :if={@results}>
      <%= if @results.everything == [] and @results.almost == [] do %>
        <div class="pt-6">
          <.empty_block chrome={:plain} title="No matches yet." message="Try removing an ingredient." />
        </div>
      <% else %>
        <div id="ingredient-summary" class="rounded-[22px] bg-accent/25 px-[18px] pt-[18px] pb-4">
          <h2 class="font-display text-[22px] font-bold leading-tight text-base-content md:text-[26px]">
            {SearchFormatting.summary_title(@terms)}
          </h2>
          <p class="mt-1 text-sm text-muted">
            {SearchFormatting.summary_subtitle(length(@results.everything), length(@results.almost))}
          </p>
        </div>
        <div class="grid gap-x-8 md:grid-cols-2">
          <.match_group
            id="ingredient-everything"
            title="You have everything"
            matches={@results.everything}
            terms={@terms}
          />
          <.match_group
            id="ingredient-almost"
            title="Almost there"
            matches={@results.almost}
            terms={@terms}
          />
        </div>
        <p class="mx-1 mt-[18px] text-[12.5px] text-muted">
          Salt, pepper, oil and water count as pantry staples.
        </p>
      <% end %>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :matches, :list, required: true
  attr :terms, :list, required: true

  defp match_group(assigns) do
    ~H"""
    <section :if={@matches != []} id={@id} class="mt-[30px] min-w-0 md:mt-[42px]">
      <.section_heading title={@title} />
      <div class="flex flex-col gap-2.5">
        <.row_card
          :for={match <- @matches}
          navigate={~p"/posts/#{match.post.id}"}
          title={Index.post_title(match.post)}
          photo_url={match.post.photo_url}
          author_name={match.post.user.username}
          author_avatar_url={match.post.user.profile_photo_url}
          detail={HomeFormatting.cook_time_label(match.post.cooking_time_minutes)}
          match={match_pill(match)}
          missing={match.missing}
          uses={uses_line(match, @terms)}
        />
      </div>
    </section>
    """
  end

  defp match_pill(%{missing: []}), do: :ready
  defp match_pill(%{missing: missing}), do: {:need, length(missing)}

  # Only "You have everything" rows say what the recipe uses; an almost-there
  # row shows what is missing instead.
  defp uses_line(%{missing: [], post: post}, terms),
    do: SearchFormatting.uses_line(terms, ingredients(post))

  defp uses_line(_match, _terms), do: nil

  defp ingredients(%{ingredients: ingredients}) when is_list(ingredients), do: ingredients
  defp ingredients(_post), do: []
end
