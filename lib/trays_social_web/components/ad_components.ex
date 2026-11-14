defmodule TraysSocialWeb.AdComponents do
  @moduledoc """
  Sponsored placement components.

    * `sponsored_slot/1`: hand-placed units on the public web recipe pages
      (W159).
    * `sponsored_card/1`: the Search grid card (W244), with the same footprint
      as `recipe_card`. It is interleaved automatically into Most saved and
      Everyone only, one card per `Monetization.ad_frequency()` recipes
      (`FeedItemJSON.interleave_ads/3`, never trailing). Most saved (10
      recipes) plus Everyone (20) keeps a Search page at two cards or fewer,
      and only when `Monetization.web_ads_enabled?/1` is true for the viewer.

  ## Density cap

  At most TWO sponsored units per page. On recipe pages they are placed by
  hand in the template —
  never by network auto-injection. If a third-party ad network is ever
  wired up, its dashboard auto-insert / "auto ads" features MUST stay off;
  the template placements are the only inventory.

  ## Layout stability (CLS)

  The slot reserves its height up front (`min-h-[250px]` / `md:min-h-[280px]`)
  so a late-loading creative never shifts the recipe content below it.

  ## Requirements before wiring a real network (follow-up)

    * Amend the router `@csp_header` with the network's script/img/frame
      origins — until then the AdSlot JS hook's injection is blocked by CSP
      (defense in depth on top of the nil-config no-op).
    * Set `config :trays_social, :web_ads` script_url/site_id (or the
      WEB_ADS_SCRIPT_URL / WEB_ADS_SITE_ID env vars in prod).
    * Turn OFF any dashboard-side auto-insert so the 2-unit cap holds.
    * Render the creative INSIDE the AdSlot hook element, never as a sibling
      of it or appended to `body`. The hook element is `isolate`, so a
      creative's own z-index stays contained there and the `z-10`
      Sponsored pill stays on top (W268).
    * Add GDPR opt-in consent (a CMP) for EEA visitors BEFORE setting
      script_url — the runtime gating here is opt-out + GPC only
      (CCPA-shaped), which is not sufficient for EEA opt-in requirements.
    * Update priv/legal/privacy.md with the partner and cookie disclosures
      (a policy that still says "no advertising cookies" must not ship with
      a live network).
  """

  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: TraysSocialWeb.Endpoint,
    router: TraysSocialWeb.Router,
    statics: TraysSocialWeb.static_paths()

  attr :id, :string, required: true, doc: "DOM id for the slot container"

  attr :position, :string,
    required: true,
    doc: "stable placement name rendered as data-ad-slot, e.g. in-content-1"

  @doc """
  A clearly labeled sponsored slot. Renders first-party house copy; the
  AdSlot JS hook only requests a network script when `:web_ads` config is
  present (and the viewer has not opted out via cookie/localStorage/GPC).
  """
  def sponsored_slot(assigns) do
    web_ads = Application.get_env(:trays_social, :web_ads, [])

    assigns =
      assigns
      |> assign(:script_url, web_ads[:script_url])
      |> assign(:site_id, web_ads[:site_id])

    ~H"""
    <div
      class="my-10 rounded-[21px] bg-base-100 p-1.5 text-base-content shadow-card"
      data-ad-slot={@position}
    >
      <%!-- W259: the pill sits over the cream-lift unit exactly as it does on
           sponsored_card's photo, so it reads in both themes. It is a sibling
           of the hook element, never inside it, so a network creative filling
           the unit cannot replace the disclosure. The hook element carries
           no vertical padding: the full 250/280 px min-height is the
           reserved creative area (see Layout stability above).
           W268: stacking. The pill carries z-10 and the hook element is
           its own stacking context (isolate), so any z-index a creative
           sets inside the unit (an iframe or a fixed div) is resolved
           inside the hook element and can never rise above the pill. The
           relative wrapper is isolated too, so the pill's z-10 stays local
           and never paints over page chrome such as a sticky bar. --%>
      <div class="relative isolate">
        <span class="absolute left-2 top-2 z-10 rounded-full bg-base-100 px-2.5 py-1 text-[11.5px] font-bold leading-none text-base-content shadow-sm">
          Sponsored
        </span>
        <div
          id={@id}
          phx-hook="AdSlot"
          phx-update="ignore"
          data-script-url={@script_url}
          data-site-id={@site_id}
          class="isolate flex min-h-[250px] md:min-h-[280px] items-center justify-center rounded-[15px] bg-cream-lift px-6 text-center"
        >
          <div class="space-y-1.5">
            <p class="max-w-[420px] text-sm leading-relaxed text-muted">
              Trays stays free for home cooks thanks to occasional, clearly labeled sponsors.
            </p>
            <p class="text-[12px] text-muted">
              Nothing in this space tracks you.
            </p>
          </div>
        </div>
      </div>
      <div class="flex min-h-[22px] items-center justify-end px-1.5 pb-1.5 pt-[9px] text-[12.5px] text-muted">
        <.link
          href={~p"/privacy/ads-choices"}
          class="shrink-0 font-semibold text-primary-ink hover:underline"
        >
          Why this ad?
        </.link>
      </div>
    </div>
    """
  end

  attr :slot, :integer, required: true, doc: "0-based ad slot index within the grid"
  attr :placement, :string, default: "find", doc: "surface name, rendered in data-ad-slot"
  attr :class, :any, default: nil

  @doc """
  Sponsored card for Search grids (W244). It has the recipe_card footprint
  (same padding, 4:3 photo, two reserved title lines, a 22px byline row), so
  a grid row with an ad stays level with its recipe cards. House copy only;
  "Why this ad?" links to the existing ads-choices page.
  """
  def sponsored_card(assigns) do
    ~H"""
    <div
      class={["min-w-0 rounded-[21px] bg-base-100 p-1.5 text-base-content shadow-card", @class]}
      data-ad-slot={"#{@placement}-#{@slot}"}
    >
      <%!-- W268: isolate keeps the pill's z-10 inside the card, so it never
           paints over the Search page's sticky z-10 search bar. --%>
      <div class="relative isolate aspect-[4/3] overflow-hidden rounded-[15px] bg-cream-lift">
        <span class="absolute left-2 top-2 z-10 rounded-full bg-base-100 px-2.5 py-1 text-[11.5px] font-bold leading-none text-base-content shadow-sm">
          Sponsored
        </span>
      </div>
      <div class="flex flex-col gap-[7px] px-1.5 pb-1.5 pt-[9px]">
        <p class="min-h-10 font-display text-base font-bold leading-tight line-clamp-2">
          Trays stays free thanks to our sponsors
        </p>
        <div class="flex min-h-[22px] min-w-0 items-center justify-between gap-2 text-[12.5px] text-muted">
          <span class="truncate">Sponsored · partner recipe</span>
          <.link
            href={~p"/privacy/ads-choices"}
            class="shrink-0 font-semibold text-primary-ink hover:underline"
          >
            Why this ad?
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
