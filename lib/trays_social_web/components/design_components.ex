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

  import TraysSocialWeb.CoreComponents, only: [icon: 1, user_avatar: 1]

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
end
