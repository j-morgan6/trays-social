defmodule TraysSocialWeb.DesignComponents do
  @moduledoc """
  Shared components from the redesign canvas (W240, "Component inventory").

  They mirror the iOS DesignSystem views from W239 (RecipeCard, RowCard,
  EndCard, chips, button styles) so both platforms share one look. Colours
  come from the theme tokens in app.css (`bg-base-100`, `text-muted`,
  `bg-cream-lift`, `bg-mint-tint`, `text-primary-ink`, ...), never raw hex,
  so light and dark mode switch with the theme.

  Screens adopt these in the W242-W252 screen tasks; the older components
  in CoreComponents stay until then.

  ## Canvas token map to Tailwind class

  | Canvas token            | Class (light / dark switch)                     |
  | ----------------------- | ----------------------------------------------- |
  | background              | `bg-base-200`                                   |
  | surface                 | `bg-base-100`                                   |
  | lift                    | `bg-base-300`                                   |
  | text                    | `text-base-content`                             |
  | muted                   | `text-muted`                                    |
  | hairline / -strong      | `border-hairline`, `border-hairline-strong`     |
  | border                  | `ring-border` / `border-border`                 |
  | primary / primaryLight  | `bg-primary`, `bg-primary-light` (alias `bg-primary-focus`) |
  | primary ink (links)     | `text-primary-ink`                              |
  | secondary (mint)        | `bg-secondary`; mint tint is `bg-mint-tint`     |
  | accent / -muted / -pressed / -border | `bg-accent`, `bg-accent/25`, `bg-accent/40`, `ring-accent/32` |
  | ink-on-accent           | `text-accent-content`                           |
  | cream                   | `bg-cream-lift` switches (cream light, lift dark); `bg-cream` is the fixed brand cream |
  | floating pill           | `bg-pill backdrop-blur-[20px]`                  |
  """
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: TraysSocialWeb.Endpoint,
    router: TraysSocialWeb.Router,
    statics: TraysSocialWeb.static_paths()

  import TraysSocialWeb.CoreComponents, only: [icon: 1, user_avatar: 1, translate_error: 1]

  alias TraysSocial.Uploads.ImageProcessor

  @aspects %{
    "4:3" => "aspect-[4/3]",
    "4:5" => "aspect-[4/5]",
    "1:1" => "aspect-square",
    "3:4" => "aspect-[3/4]",
    "3:2" => "aspect-[3/2]"
  }

  @chromes %{card: "rounded-3xl bg-cream-lift", plain: ""}

  @pill_base "inline-flex min-h-[50px] items-center justify-center gap-2.5 rounded-full px-[22px] text-[15.5px] font-semibold transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:cursor-not-allowed disabled:opacity-55"

  @pulse "bg-base-300 animate-pulse motion-reduce:animate-none"

  # ---------------------------------------------------------------------------
  # Recipe card
  # ---------------------------------------------------------------------------

  @doc """
  Recipe card for Jump back in, the follows row and every masonry grid: a soft
  surface card with the photo, an optional cook-time pill on the photo, an
  optional badge, the title and the cook's byline.

  ## Examples

      <.recipe_card
        navigate={~p"/posts/\#{post.id}"}
        title={post.title}
        photo_url={post.photo_url}
        aspect="4:5"
        cook_time="40 min"
        badge={:new}
        author_name={post.user.username}
        context="Yesterday"
      />
  """
  attr :navigate, :string, required: true, doc: "where the card links to"
  attr :title, :string, required: true
  attr :photo_url, :string, default: nil, doc: "original upload URL; the medium variant is shown"

  attr :aspect, :string,
    default: "4:3",
    values: ~w(4:3 4:5 1:1 3:4 3:2),
    doc: "photo aspect ratio"

  attr :cook_time, :string, default: nil, doc: "shown as a pill on the photo, recipes only"
  attr :badge, :any, default: nil, doc: "`:new`, `{:rank, n}` or nil"

  attr :kind, :atom,
    default: :recipe,
    values: [:recipe, :photo_post],
    doc: "legacy photo posts get a Photo tag"

  attr :author_name, :string,
    default: nil,
    doc: "nil on a cook's own tray or profile, where every card is theirs"

  attr :author_avatar_url, :string, default: nil
  attr :context, :string, default: nil, doc: "byline context, e.g. Opened today"
  attr :class, :any, default: nil
  attr :rest, :global

  def recipe_card(assigns) do
    assigns =
      assigns
      |> assign(:aspect_class, Map.fetch!(@aspects, assigns.aspect))
      |> assign(:tag, card_tag(assigns.kind, assigns.badge))
      |> assign(:image_url, ImageProcessor.medium_url(assigns.photo_url))

    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "group block rounded-[21px] bg-base-100 p-1.5 text-base-content shadow-card focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary",
        @class
      ]}
      {@rest}
    >
      <div class={["relative overflow-hidden rounded-[15px] bg-cream-lift", @aspect_class]}>
        <img
          :if={@image_url}
          src={@image_url}
          alt=""
          loading="lazy"
          decoding="async"
          class="absolute inset-0 size-full object-cover"
        />
        <span
          :if={@tag}
          class={[
            "absolute left-2 top-2 rounded-full px-2.5 py-1 text-[11.5px] font-bold leading-none",
            @tag.class
          ]}
        >
          {@tag.label}
        </span>
        <span
          :if={@kind == :recipe and @cook_time}
          class="absolute bottom-2 left-2 rounded-full bg-pill px-[9px] py-1 text-xs font-semibold leading-none text-base-content backdrop-blur-[20px]"
        >
          {@cook_time}
        </span>
      </div>
      <div class="flex flex-col gap-[7px] px-1.5 pb-1.5 pt-[9px]">
        <%!-- min-h-10 reserves both title lines (2 x 20px line height), so a
             one-line title gives the same card height as a two-line one.
             Both title variants share it, so a photo post is as tall as a
             recipe and rows stay level. --%>
        <h3
          :if={@kind == :recipe}
          class="min-h-10 font-display text-base font-bold leading-tight line-clamp-2"
        >
          {@title}
        </h3>
        <p :if={@kind == :photo_post} class="min-h-10 text-sm leading-5 line-clamp-2">
          {@title}
        </p>
        <.byline name={@author_name} avatar_url={@author_avatar_url} context={@context} />
      </div>
    </.link>
    """
  end

  defp card_tag(:photo_post, _badge),
    do: %{label: "Photo", class: "bg-base-100 text-base-content shadow-sm"}

  defp card_tag(:recipe, :new), do: %{label: "New", class: "bg-accent text-accent-content"}

  defp card_tag(:recipe, {:rank, rank}),
    do: %{label: "##{rank}", class: "bg-accent text-accent-content"}

  defp card_tag(:recipe, nil), do: nil

  attr :name, :string, default: nil
  attr :avatar_url, :string, default: nil
  attr :context, :string, default: nil

  # min-h-[22px] is the avatar's height, so a byline without the cook's name
  # (W246: own tray, profile) keeps the card's footprint.
  defp byline(assigns) do
    ~H"""
    <div class="flex min-h-[22px] min-w-0 items-center gap-1.5 overflow-hidden whitespace-nowrap text-[12.5px] text-muted">
      <.user_avatar :if={@name} username={@name} photo_url={@avatar_url} size="xs" class="shrink-0" />
      <span :if={@name} class="truncate font-semibold text-base-content">{@name}</span>
      <span :if={@name && @context} aria-hidden="true">·</span>
      <span :if={@context} class="truncate">{@context}</span>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Row card
  # ---------------------------------------------------------------------------

  @doc """
  Row card for Search groups and ingredient results: a small surface card with
  a square photo, the title, the byline, an optional match pill and either the
  missing ingredients or what the recipe uses.

  ## Examples

      <.row_card
        navigate={~p"/posts/\#{post.id}"}
        title="Ginger chicken rice bowls"
        author_name="noor"
        detail="30 min"
        match={{:need, 2}}
        missing={["soy sauce", "ginger"]}
      />
  """
  attr :navigate, :string, required: true
  attr :title, :string, required: true
  attr :photo_url, :string, default: nil, doc: "original upload URL; the thumb variant is shown"
  attr :author_name, :string, default: nil
  attr :author_avatar_url, :string, default: nil
  attr :detail, :string, default: nil, doc: "byline context, e.g. 35 min"
  attr :match, :any, default: nil, doc: "`:ready`, `{:need, n}` or nil"
  attr :uses, :string, default: nil, doc: "e.g. Uses chicken, rice"
  attr :missing, :list, default: [], doc: "ingredient names the cook still needs"
  attr :class, :any, default: nil
  attr :rest, :global

  def row_card(assigns) do
    assigns = assign(assigns, :image_url, ImageProcessor.thumb_url(assigns.photo_url))

    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "flex items-center gap-3.5 rounded-[20px] bg-base-100 py-2 pl-2 pr-3 text-base-content shadow-card focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary",
        @class
      ]}
      {@rest}
    >
      <div class="relative size-[84px] shrink-0 overflow-hidden rounded-[14px] bg-cream-lift">
        <img
          :if={@image_url}
          src={@image_url}
          alt=""
          loading="lazy"
          decoding="async"
          class="absolute inset-0 size-full object-cover"
        />
      </div>
      <div class="flex min-w-0 flex-1 flex-col gap-[5px]">
        <h3 class="truncate font-display text-base font-bold leading-tight">{@title}</h3>
        <.byline
          :if={@author_name || @detail}
          name={@author_name}
          avatar_url={@author_avatar_url}
          context={@detail}
        />
        <div
          :if={@match || @missing != [] || @uses}
          class="flex flex-wrap items-center gap-x-2 gap-y-1"
        >
          <.match_pill :if={@match} match={@match} />
          <span :if={@missing != []} class="text-[12.5px] text-muted">
            <span class="font-semibold text-base-content">missing:</span>
            {Enum.join(@missing, ", ")}
          </span>
          <span :if={@missing == [] && @uses} class="truncate text-[12.5px] text-muted">{@uses}</span>
        </div>
      </div>
      <.icon name="hero-chevron-right" class="size-4 shrink-0 text-muted" />
    </.link>
    """
  end

  attr :match, :any, required: true

  defp match_pill(%{match: :ready} = assigns) do
    ~H"""
    <span class="rounded-full bg-mint-tint px-2.5 py-1 text-xs font-bold leading-none text-primary-ink">
      Ready to cook
    </span>
    """
  end

  defp match_pill(%{match: {:need, _count}} = assigns) do
    ~H"""
    <span class="rounded-full bg-accent/25 px-2.5 py-1 text-xs font-bold leading-none text-base-content">
      Need {elem(@match, 1)}
    </span>
    """
  end

  # ---------------------------------------------------------------------------
  # End card
  # ---------------------------------------------------------------------------

  @doc """
  End card that closes a finite row (New from people you follow), so it never
  scrolls forever.

  ## Examples

      <.end_card title="You are caught up" message="That is everything from the last 7 days." />
  """
  attr :title, :string, required: true
  attr :message, :string, required: true
  attr :icon, :string, default: "hero-check", doc: "a literal hero-* icon name"
  attr :class, :any, default: nil
  attr :rest, :global

  def end_card(assigns) do
    ~H"""
    <div
      class={["flex flex-col items-start gap-2 rounded-[21px] bg-mint-tint px-[18px] py-5", @class]}
      {@rest}
    >
      <.icon name={@icon} class="size-[18px] text-primary-ink" />
      <p class="font-display text-[17px] font-bold leading-tight text-base-content">{@title}</p>
      <p class="text-[13.5px] leading-snug text-muted">{@message}</p>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Section heading
  # ---------------------------------------------------------------------------

  @doc """
  Sentence-case section heading with an optional aside and See all link. It
  replaces the old small uppercase section labels.

  ## Examples

      <.section_heading title="Friends' trays" see_all={~p"/my-tray"} />
      <.section_heading title="My recipes" aside="Newest first" />
  """
  attr :title, :string, required: true
  attr :aside, :string, default: nil, doc: "muted note after the title"
  attr :see_all, :string, default: nil, doc: "path for the See all link"
  attr :see_all_label, :string, default: "See all"
  attr :class, :any, default: nil
  attr :rest, :global

  def section_heading(assigns) do
    ~H"""
    <div
      class={[
        "mt-[42px] mb-4 flex min-h-[26px] items-baseline justify-between gap-3 first:mt-0",
        @class
      ]}
      {@rest}
    >
      <h2 class="font-display text-[22px] font-bold leading-tight tracking-[-0.01em] text-base-content">
        {@title}
        <span :if={@aside} class="ml-1.5 text-[13.5px] font-medium tracking-normal text-muted">
          {@aside}
        </span>
      </h2>
      <.link
        :if={@see_all}
        navigate={@see_all}
        class="-my-3 inline-flex min-h-11 shrink-0 items-center pl-3 text-[14.5px] font-semibold text-primary-ink hover:underline"
      >
        {@see_all_label}
      </.link>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Segmented pills
  # ---------------------------------------------------------------------------

  @doc """
  List switch (canvas "Segmented pills", iOS `SegmentedPills`): equal pills on
  a lift track; the selected one sits on the surface. Each option is a patch
  link, so the choice lives in the URL. A count shows when it is known.

  ## Examples

      <.segmented_pills
        id="my-tray-switch"
        label="My Tray lists"
        options={[
          %{label: "My recipes", count: 7, patch: ~p"/my-tray", selected: true},
          %{label: "Saved", count: 8, patch: ~p"/my-tray?list=saved", selected: false}
        ]}
      />
  """
  attr :id, :string, required: true
  attr :label, :string, required: true, doc: "accessible name for the switch"

  attr :options, :list,
    required: true,
    doc: "maps with :label, :patch, :selected and an optional :count (nil hides it)"

  attr :class, :any, default: nil

  def segmented_pills(assigns) do
    ~H"""
    <nav id={@id} aria-label={@label} class={["flex gap-1 rounded-full bg-base-300 p-1", @class]}>
      <.link
        :for={option <- @options}
        patch={option.patch}
        aria-current={option.selected && "page"}
        class={[
          "flex min-h-11 min-w-0 flex-1 items-center justify-center gap-1.5 rounded-full px-4 text-[15px] font-semibold transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary",
          pill_state_class(option.selected)
        ]}
      >
        <span class="truncate">{option.label}</span>
        <span :if={option[:count]} class="opacity-75">{option.count}</span>
      </.link>
    </nav>
    """
  end

  defp pill_state_class(true), do: "bg-base-100 text-base-content shadow-card"
  defp pill_state_class(_selected), do: "text-muted hover:text-base-content"

  @doc """
  The form-field twin of `segmented_pills/1`: the same pills on the same
  lift track, but each pill is a radio input, so the choice travels with
  the form's params instead of the URL and switching never re-renders what
  the user typed (W262). The checked pill sits on the surface by CSS alone.

  ## Examples

      <.segmented_choice
        id="feedback-kind"
        field={@form[:kind]}
        label="What are you sending?"
        options={[{"Bug", "bug"}, {"Feedback", "feedback"}]}
      />
  """
  attr :id, :string, required: true
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true, doc: "the fieldset's accessible name"
  attr :options, :list, required: true, doc: "{label, value} tuples"
  attr :class, :any, default: nil

  def segmented_choice(assigns) do
    assigns = assign(assigns, :checked, to_string(assigns.field.value))

    ~H"""
    <fieldset id={@id} class={["min-w-0", @class]}>
      <legend class="sr-only">{@label}</legend>
      <div class="flex gap-1 rounded-full bg-base-300 p-1">
        <label
          :for={{label, value} <- @options}
          for={"#{@field.id}_#{value}"}
          class={[
            "flex min-h-11 min-w-0 flex-1 cursor-pointer items-center justify-center rounded-full px-4 text-[15px] font-semibold transition-colors",
            "text-muted hover:text-base-content",
            "has-checked:bg-base-100 has-checked:text-base-content has-checked:shadow-card",
            "has-focus-visible:outline-2 has-focus-visible:outline-offset-2 has-focus-visible:outline-primary"
          ]}
        >
          <input
            type="radio"
            id={"#{@field.id}_#{value}"}
            name={@field.name}
            value={value}
            checked={@checked == value}
            class="sr-only"
          />
          <span class="truncate">{label}</span>
        </label>
      </div>
    </fieldset>
    """
  end

  # ---------------------------------------------------------------------------
  # Chips
  # ---------------------------------------------------------------------------

  @doc """
  Ingredient chip under the search field, with a remove button (32px hit
  area). Pass phx-click, phx-value-* and phx-target; they go on the button.

  ## Examples

      <.ingredient_chip name="chicken" phx-click="remove-ingredient" phx-value-ingredient="chicken" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: nil
  attr :rest, :global, doc: "applied to the remove button"

  def ingredient_chip(assigns) do
    ~H"""
    <span class={[
      "inline-flex h-10 max-w-full items-center gap-0.5 rounded-full bg-accent/25 pl-[15px] pr-1 text-[14.5px] font-semibold text-base-content ring-1 ring-inset ring-accent/32",
      @class
    ]}>
      <span class="min-w-0 truncate">{@name}</span>
      <button
        type="button"
        aria-label={"Remove #{@name}"}
        class="grid size-8 shrink-0 place-items-center rounded-full hover:bg-accent/40 active:bg-accent/40 focus-visible:outline-2 focus-visible:outline-primary"
        {@rest}
      >
        <.icon name="hero-x-mark" class="size-4" />
      </button>
    </span>
    """
  end

  @doc """
  Recently used ingredient chip with a plus. Pass phx-click and phx-value-*.

  ## Examples

      <.recent_chip name="garlic" phx-click="add-ingredient" phx-value-ingredient="garlic" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  def recent_chip(assigns) do
    ~H"""
    <button
      type="button"
      aria-label={"Add #{@name}"}
      class={[
        "inline-flex h-10 max-w-full items-center gap-1.5 rounded-full bg-base-100 pl-3 pr-[15px] text-[14.5px] font-medium text-base-content ring-1 ring-inset ring-border hover:bg-base-300 focus-visible:outline-2 focus-visible:outline-primary",
        @class
      ]}
      {@rest}
    >
      <.icon name="hero-plus" class="size-4 shrink-0 text-primary-ink" />
      <span class="min-w-0 truncate">{@name}</span>
    </button>
    """
  end

  # ---------------------------------------------------------------------------
  # Empty-state block
  # ---------------------------------------------------------------------------

  @doc """
  Empty-state block: one rounded headline, one plain sentence, at most one
  action. `chrome={:card}` sits on a cream card (lift in dark); Search empties
  use `chrome={:plain}` and sit on the background.

  ## Examples

      <.empty_block title="Nothing saved yet." message="Save a recipe and it waits here.">
        <:action><.primary_button navigate={~p"/search"}>Find recipes</.primary_button></:action>
      </.empty_block>
  """
  attr :title, :string, required: true
  attr :message, :string, default: nil
  attr :chrome, :atom, default: :card, values: [:card, :plain]
  attr :class, :any, default: nil
  attr :rest, :global
  slot :action, doc: "at most one action"

  def empty_block(assigns) do
    assigns = assign(assigns, :chrome_class, Map.fetch!(@chromes, assigns.chrome))

    ~H"""
    <div
      class={[
        "flex flex-col items-center gap-2.5 px-[22px] py-8 text-center",
        @chrome_class,
        @class
      ]}
      {@rest}
    >
      <p class="font-display text-[23px] font-extrabold leading-tight tracking-[-0.02em] text-base-content">
        {@title}
      </p>
      <p :if={@message} class="max-w-[300px] text-[15px] leading-normal text-muted">{@message}</p>
      <div :if={@action != []} class="mt-2">{render_slot(@action)}</div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Skeletons
  # ---------------------------------------------------------------------------

  @doc """
  Loading placeholder shaped like a recipe card. No spinner; the pulse stops
  under Reduce Motion.
  """
  attr :aspect, :string, default: "4:3", values: ~w(4:3 4:5 1:1 3:4 3:2)
  attr :class, :any, default: nil

  def skeleton_card(assigns) do
    assigns =
      assigns
      |> assign(:aspect_class, Map.fetch!(@aspects, assigns.aspect))
      |> assign(:pulse, @pulse)

    ~H"""
    <div aria-hidden="true" class={["rounded-[21px] bg-base-100 p-1.5 pb-3 shadow-card", @class]}>
      <div class={["rounded-[14px]", @pulse, @aspect_class]}></div>
      <div class={["ml-1.5 mt-3 h-[11px] w-4/5 rounded-md", @pulse]}></div>
      <div class={["ml-1.5 mt-2 h-[11px] w-1/2 rounded-md", @pulse]}></div>
    </div>
    """
  end

  @doc """
  Loading placeholder shaped like a row card.
  """
  attr :class, :any, default: nil

  def skeleton_row(assigns) do
    assigns = assign(assigns, :pulse, @pulse)

    ~H"""
    <div
      aria-hidden="true"
      class={[
        "flex items-center gap-3.5 rounded-[20px] bg-base-100 py-2 pl-2 pr-3 shadow-card",
        @class
      ]}
    >
      <div class={["size-[84px] shrink-0 rounded-[14px]", @pulse]}></div>
      <div class="flex flex-1 flex-col gap-2">
        <div class={["h-[11px] w-[70%] rounded-md", @pulse]}></div>
        <div class={["h-[11px] w-2/5 rounded-md", @pulse]}></div>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Buttons
  # ---------------------------------------------------------------------------

  @doc """
  Primary action: emerald pill, at least 50px high. Renders a link when given
  href, navigate or patch, otherwise a button.

  ## Examples

      <.primary_button navigate={~p"/posts/new"}>Post your first recipe</.primary_button>
  """
  attr :wide, :boolean, default: false, doc: "stretch to the full width"
  attr :class, :any, default: nil

  attr :rest, :global,
    include: ~w(href navigate patch method download name value disabled type form)

  slot :inner_block, required: true

  def primary_button(assigns) do
    assigns
    |> assign(:variant_class, "bg-primary text-primary-content hover:bg-primary-light")
    |> pill_button()
  end

  @doc """
  Quiet secondary action: surface pill with a hairline ring.
  """
  attr :wide, :boolean, default: false, doc: "stretch to the full width"
  attr :class, :any, default: nil

  attr :rest, :global,
    include: ~w(href navigate patch method download name value disabled type form)

  slot :inner_block, required: true

  def secondary_button(assigns) do
    assigns
    |> assign(
      :variant_class,
      "bg-base-100 text-base-content ring-1 ring-inset ring-hairline-strong hover:bg-base-300"
    )
    |> pill_button()
  end

  @doc """
  Amber "make something" action (Create, the Plus call to action).
  """
  attr :wide, :boolean, default: false, doc: "stretch to the full width"
  attr :class, :any, default: nil

  attr :rest, :global,
    include: ~w(href navigate patch method download name value disabled type form)

  slot :inner_block, required: true

  def accent_button(assigns) do
    assigns
    |> assign(:variant_class, "bg-accent text-accent-content hover:brightness-95")
    |> pill_button()
  end

  defp pill_button(assigns) do
    assigns =
      assign(assigns, :classes, [
        @pill_base,
        assigns.wide && "w-full",
        assigns.variant_class,
        assigns.class
      ])

    if assigns.rest[:href] || assigns.rest[:navigate] || assigns.rest[:patch] do
      ~H"""
      <.link class={@classes} {@rest}>{render_slot(@inner_block)}</.link>
      """
    else
      ~H"""
      <button class={@classes} {@rest}>{render_slot(@inner_block)}</button>
      """
    end
  end

  @doc """
  Follow toggle. Pass phx-click and phx-value-* for the toggle event.

  ## Examples

      <.follow_button following={@following?} phx-click="toggle-follow" />
  """
  attr :following, :boolean, required: true
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(name value disabled form)

  def follow_button(assigns) do
    assigns = assign(assigns, :state_class, follow_class(assigns.following))

    ~H"""
    <button
      type="button"
      aria-pressed={to_string(@following)}
      class={[
        "inline-flex min-h-11 min-w-[100px] items-center justify-center rounded-full px-4 text-sm font-semibold transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary",
        @state_class,
        @class
      ]}
      {@rest}
    >
      {if @following, do: "Following", else: "Follow"}
    </button>
    """
  end

  defp follow_class(true), do: "bg-base-300 text-base-content"
  defp follow_class(false), do: "bg-primary text-primary-content hover:bg-primary-light"
  # ---------------------------------------------------------------------------
  # Sign-in (WebAuth artboard)
  # ---------------------------------------------------------------------------

  @brand_tiles [
    {"hero-book-open", "Keep the recipes you love"},
    {"hero-user-group", "See what friends cook"},
    {"hero-shopping-bag", "Cook from what you have"}
  ]

  @doc """
  The split-panel sign-in shell: the emerald brand panel (lockup, eyebrow,
  headline and three tiles) beside the form. At phone width the panel
  shrinks to the lockup and eyebrow, and the form sits under it on a
  rounded sheet. The panel stays emerald in dark mode, as on the canvas.

  ## Examples

      <.auth_shell>
        <.auth_heading title="Welcome back" subtitle="Log in to get back to your tray." />
        ...
      </.auth_shell>
  """
  attr :rest, :global
  slot :inner_block, required: true

  def auth_shell(assigns) do
    assigns = assign(assigns, :tiles, @brand_tiles)

    ~H"""
    <div class="-mt-8 lg:mx-auto lg:mt-0 lg:max-w-[1280px] lg:px-6" {@rest}>
      <div class="flex flex-col overflow-hidden lg:min-h-[760px] lg:flex-row lg:rounded-[14px] lg:shadow-card lg:ring-1 lg:ring-hairline-strong">
        <section
          aria-label="Trays"
          class="flex flex-none flex-col items-center bg-primary px-[22px] pt-[26px] pb-11 text-center text-cream lg:w-[46%] lg:items-start lg:px-[52px] lg:py-11 lg:text-left"
        >
          <div class="flex items-center gap-3">
            <img
              src={~p"/images/logo-on-dark.svg"}
              alt=""
              width="52"
              height="41"
              class="h-auto w-11 lg:w-[52px]"
            />
            <span class="font-display text-[30px] font-black leading-none tracking-[-1px] lg:text-[34px]">
              Trays
            </span>
          </div>
          <p class="mt-3 text-xs font-semibold uppercase tracking-[2.4px] text-accent">
            Recipes worth keeping
          </p>
          <div class="hidden flex-1 flex-col justify-center gap-6 lg:flex">
            <p class="max-w-[440px] font-display text-[44px] font-extrabold leading-[1.1] tracking-[-0.02em]">
              A quiet place to cook.
            </p>
            <ul class="grid max-w-[470px] grid-cols-3 gap-3">
              <li
                :for={{icon, label} <- @tiles}
                class="flex min-h-28 flex-col justify-between gap-3 rounded-[18px] bg-cream/10 px-3.5 py-4 ring-1 ring-inset ring-cream/16"
              >
                <.icon name={icon} class="size-5" />
                <span class="font-display text-[15px] font-extrabold leading-[1.25]">{label}</span>
              </li>
            </ul>
          </div>
          <p class="hidden text-[13px] text-cream/85 lg:block">Also on iPhone.</p>
        </section>

        <section class="relative -mt-[22px] flex flex-1 justify-center rounded-t-3xl bg-base-200 px-[22px] pb-7 lg:mt-0 lg:items-center lg:rounded-none lg:p-10">
          <div class="w-full max-w-[400px] pt-[26px] lg:pt-0">
            {render_slot(@inner_block)}
          </div>
        </section>
      </div>
    </div>
    """
  end

  @doc """
  The sign-in page heading: rounded sans title and a muted line under it.
  """
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :inner_block, doc: "rich subtitle content, used in place of `subtitle`"

  def auth_heading(assigns) do
    ~H"""
    <h1 class="font-display text-[28px] font-extrabold leading-[1.15] tracking-[-0.02em] text-base-content break-words lg:text-[32px]">
      {@title}
    </h1>
    <p
      :if={@subtitle || @inner_block != []}
      class="mt-1.5 text-[15px] leading-[1.45] text-muted break-words"
    >
      {@subtitle}{render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  A labelled sign-in field: 13.5 semibold label 8px above a 50px surface
  field with a strong hairline, the amber focus ring, and amber field
  errors under it. Takes a form field like `<.input>`; the input keeps the
  field's name and id, so form params are unchanged.

  ## Examples

      <.auth_input field={f[:email]} type="email" label="Email" autocomplete="email" required />
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :type, :string, default: "text", values: ~w(email password text)
  attr :label, :string, required: true
  attr :hint, :string, default: nil, doc: "muted note under the field"
  attr :id, :any, default: nil

  attr :rest, :global,
    include: ~w(autocomplete disabled maxlength minlength placeholder readonly required)

  slot :aside, doc: "shown at the end of the label row, e.g. a Forgot password? link"

  def auth_input(assigns) do
    field = assigns.field
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns =
      assigns
      |> assign(:id, assigns.id || field.id)
      |> assign(:name, field.name)
      |> assign(:value, field_value(assigns.type, field.value))
      |> assign(:errors, Enum.map(errors, &translate_error/1))

    ~H"""
    <div class="flex flex-col gap-2">
      <div class="flex min-h-5 items-center justify-between gap-3">
        <label for={@id} class="text-[13.5px] font-semibold text-base-content">{@label}</label>
        {render_slot(@aside)}
      </div>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={@value}
        aria-invalid={@errors != [] && "true"}
        class={[
          "min-h-[50px] w-full rounded-[14px] bg-base-100 px-4 text-base text-base-content",
          "placeholder:text-muted outline-none read-only:text-muted",
          "focus:ring-[1.5px] focus:ring-accent focus:outline-4 focus:outline-solid focus:outline-accent/25",
          if(@errors != [],
            do: "ring-[1.5px] ring-inset ring-accent",
            else: "ring-1 ring-inset ring-hairline-strong"
          )
        ]}
        {@rest}
      />
      <span :if={@hint} class="text-[13px] text-muted">{@hint}</span>
      <.field_error :for={msg <- @errors}>{msg}</.field_error>
    </div>
    """
  end

  defp checkbox_checked?(nil, default), do: default

  defp checkbox_checked?(value, _default),
    do: Phoenix.HTML.Form.normalize_value("checkbox", value)

  # A password is never written back into the page, so a failed log-in or
  # registration does not echo what was typed into the HTML response.
  defp field_value("password", _value), do: nil
  defp field_value(type, value), do: Phoenix.HTML.Form.normalize_value(type, value)

  @doc """
  A sign-in checkbox row, 44px high, emerald when on, with amber field
  errors under it. Sends "false" when unchecked, like `<.input type="checkbox">`.
  `default` is the state before the field has a value (Keep me logged in
  starts on); once the form is re-rendered with params, the submitted value
  wins, so a box the user unchecked stays unchecked after a failed attempt.
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :default, :boolean, default: false, doc: "checked when the field has no value yet"
  attr :rest, :global, include: ~w(required disabled)

  def auth_checkbox(assigns) do
    field = assigns.field
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns =
      assigns
      |> assign(:id, field.id)
      |> assign(:name, field.name)
      |> assign(:errors, Enum.map(errors, &translate_error/1))
      |> assign(:is_checked, checkbox_checked?(field.value, assigns.default))

    ~H"""
    <div class="flex flex-col gap-2">
      <input type="hidden" name={@name} value="false" />
      <label class="flex min-h-11 cursor-pointer items-center gap-2.5 text-[15px] text-base-content">
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@is_checked}
          class="checkbox checkbox-sm rounded-[7px] border-hairline-strong checked:border-primary checked:bg-primary checked:text-primary-content"
          {@rest}
        />
        {@label}
      </label>
      <.field_error :for={msg <- @errors}>{msg}</.field_error>
    </div>
    """
  end

  @doc """
  The mint "check your email" box: an in-place status (a sent sign-in link,
  the verify-email gate), mint tint at 35% / 14%, radius 18.
  """
  attr :title, :string, default: nil
  attr :icon, :string, default: "hero-envelope", doc: "the leading Heroicon"
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def auth_status(assigns) do
    ~H"""
    <div
      role="status"
      class={["flex items-start gap-3 rounded-[18px] bg-mint-tint p-4 text-base-content", @class]}
      {@rest}
    >
      <.icon name={@icon} class="mt-0.5 size-5 shrink-0" />
      <div class="min-w-0">
        <p :if={@title} class="mb-1 font-display text-[17px] font-extrabold">{@title}</p>
        <p class="text-[14.5px] leading-[1.45] break-words">{render_slot(@inner_block)}</p>
      </div>
    </div>
    """
  end

  @doc """
  An amber field error, in place under the field it belongs to.
  """
  slot :inner_block, required: true

  def field_error(assigns) do
    ~H"""
    <p class="flex items-start gap-2 rounded-xl bg-accent/25 px-3 py-2 text-[13.5px] leading-[1.4] text-base-content">
      <.icon name="hero-exclamation-circle" class="mt-px size-4 shrink-0" />
      <span>{render_slot(@inner_block)}</span>
    </p>
    """
  end

  @doc """
  The single error callout: amber-muted fill, amber-border ring, radius 14.
  Sits directly above the primary button on the sign-in pages.
  """
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def callout(assigns) do
    ~H"""
    <div
      role="alert"
      class={[
        "flex items-start gap-2.5 rounded-[14px] bg-accent/25 px-3.5 py-3 text-[14.5px] leading-[1.4] text-base-content ring-1 ring-inset ring-accent/32",
        @class
      ]}
      {@rest}
    >
      <.icon name="hero-exclamation-circle" class="mt-px size-5 shrink-0" />
      <span>{render_slot(@inner_block)}</span>
    </div>
    """
  end

  @doc """
  The "or with email" divider between Continue with Apple and the form.
  """
  attr :label, :string, default: "or with email"

  def or_divider(assigns) do
    ~H"""
    <div class="flex items-center gap-3 text-[13px] text-muted before:h-px before:flex-1 before:bg-hairline-strong after:h-px after:flex-1 after:bg-hairline-strong">
      {@label}
    </div>
    """
  end

  @doc """
  Continue with Apple: a dark pill in light mode and a light pill in dark
  mode, from the text and surface tokens so it follows the theme, including
  the system setting.
  """
  attr :label, :string, default: "Continue with Apple"

  def apple_button(assigns) do
    ~H"""
    <.link
      navigate={~p"/auth/apple/start"}
      class="inline-flex min-h-[52px] w-full items-center justify-center gap-2 rounded-full bg-base-content text-base font-semibold text-base-100 transition-opacity hover:opacity-90"
      aria-label={@label}
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 17 17"
        class="size-5 fill-current"
        aria-hidden="true"
      >
        <path d="M12.152 0c-.943.061-2.05.654-2.7 1.43-.59.71-1.083 1.764-.892 2.787 1.026.031 2.087-.575 2.713-1.366.582-.736 1.026-1.789.879-2.851zM15.97 12.18a4.49 4.49 0 0 1-.62 1.14c-.39.55-.71.93-.95 1.14-.39.36-.81.55-1.26.56-.32 0-.71-.09-1.16-.28-.46-.19-.88-.28-1.27-.28-.41 0-.84.09-1.3.28-.47.19-.85.29-1.13.3-.43.02-.86-.17-1.28-.58-.27-.23-.6-.62-.99-1.17-.42-.59-.77-1.28-1.04-2.06C5.66 10.5 5.5 9.43 5.5 8.4c0-1.18.26-2.2.78-3.05.41-.69.95-1.23 1.63-1.63.68-.4 1.41-.6 2.21-.62.34 0 .79.1 1.34.31.55.21.91.31 1.07.31.12 0 .51-.12 1.18-.36.63-.22 1.16-.32 1.6-.28 1.18.09 2.07.55 2.66 1.36-1.06.64-1.59 1.54-1.58 2.7 0 .9.33 1.65.98 2.24.29.28.62.5.98.65-.08.22-.16.43-.25.63z" />
      </svg>
      {@label}
    </.link>
    """
  end
end
