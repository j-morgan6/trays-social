defmodule TraysSocialWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use TraysSocialWeb, :html

  embed_templates "page_html/*"

  @app_store_url "https://apps.apple.com/app/id6762027510"

  @doc "The live Trays listing on the App Store."
  def app_store_url, do: @app_store_url

  @doc """
  The Trays Plus price lines and legal links, shared by both landing page
  versions. paid_tier (W211) decides whether a price and trial are named:
  until Plus can be bought, the page says it is coming and names no price.
  """
  attr :paid_tier, :boolean, required: true

  def plus_pricing(assigns) do
    ~H"""
    <%= if @paid_tier do %>
      <p class="text-[15px] text-base-content leading-[1.55]">
        <span class="font-semibold">$3.99 per month or $29.99 per year</span>
        in the United States, with a 7-day free trial on both.
      </p>
      <p class="mt-2 text-[13px] text-base-content/60 leading-[1.55] max-w-[620px]">
        Trays Plus is sold through the App Store. The price in your local
        currency is shown before you confirm, and that is what you pay.
        Subscriptions renew automatically until cancelled, and you cancel any
        time in your Apple subscription settings.
      </p>
    <% else %>
      <p class="text-[15px] text-base-content leading-[1.55]">
        <span class="font-semibold">Trays Plus is coming in a future update.</span>
        It is not available to buy yet.
      </p>
      <p class="mt-2 text-[13px] text-base-content/60 leading-[1.55] max-w-[620px]">
        Everything on Trays is free to use today. When Plus arrives, it will
        be offered in the iOS app, and the price is shown there before you
        decide.
      </p>
    <% end %>
    <nav class="mt-4 flex flex-wrap items-center gap-x-5 gap-y-2 text-[13px] text-base-content/60">
      <.link href={~p"/terms"} class="underline hover:text-base-content transition-colors">
        Terms of Service
      </.link>
      <.link href={~p"/privacy"} class="underline hover:text-base-content transition-colors">
        Privacy Policy
      </.link>
      <.link href={~p"/faq"} class="underline hover:text-base-content transition-colors">
        What Plus includes
      </.link>
    </nav>
    """
  end

  @doc "The landing page footer, shared by both landing page versions."
  def landing_footer(assigns) do
    ~H"""
    <footer class="max-w-[1000px] mx-auto border-t border-base-300 pt-8 pb-4">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 text-[13px] text-base-content/60">
        <span class="font-display font-bold text-primary text-[20px] leading-none">Trays</span>
        <nav class="flex flex-wrap items-center gap-x-5 gap-y-2">
          <.link href={~p"/faq"} class="hover:text-base-content transition-colors">FAQ</.link>
          <.link href={~p"/privacy"} class="hover:text-base-content transition-colors">
            Privacy
          </.link>
          <.link href={~p"/terms"} class="hover:text-base-content transition-colors">Terms</.link>
          <.link href={~p"/community-guidelines"} class="hover:text-base-content transition-colors">
            Community Guidelines
          </.link>
          <a href="mailto:support@trays.app" class="hover:text-base-content transition-colors">
            support@trays.app
          </a>
        </nav>
      </div>
      <p class="mt-6 text-[12px] text-base-content/50">
        Joser Labs Inc.
      </p>
    </footer>
    """
  end
end
