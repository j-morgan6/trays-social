defmodule TraysSocialWeb.AdComponents do
  @moduledoc """
  Sponsored placement components for the public web recipe pages (W159).

  ## Density cap

  At most TWO sponsored units per page, placed by hand in the template —
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
    * Add GDPR opt-in consent (a CMP) for EEA visitors BEFORE setting
      script_url — the runtime gating here is opt-out + GPC only
      (CCPA-shaped), which is not sufficient for EEA opt-in requirements.
    * Update priv/legal/privacy.md with the partner and cookie disclosures
      (a policy that still says "no advertising cookies" must not ship with
      a live network).
  """

  use Phoenix.Component

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
    <div class="my-10" data-ad-slot={@position}>
      <div class="font-mono text-[10px] uppercase tracking-[0.14em] text-base-content/60 mb-2">
        Sponsored
      </div>
      <div
        id={@id}
        phx-hook="AdSlot"
        phx-update="ignore"
        data-script-url={@script_url}
        data-site-id={@site_id}
        class="flex items-center justify-center min-h-[250px] md:min-h-[280px] border border-base-300 rounded-sm bg-base-200/40 px-6 text-center"
      >
        <div class="space-y-1.5">
          <p class="text-sm text-base-content/70 max-w-[420px] leading-relaxed">
            Trays stays free for home cooks thanks to occasional, clearly labeled sponsors.
          </p>
          <p class="text-[12px] text-base-content/50">
            Nothing in this space tracks you.
          </p>
        </div>
      </div>
    </div>
    """
  end
end
