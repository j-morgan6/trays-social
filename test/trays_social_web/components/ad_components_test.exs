defmodule TraysSocialWeb.AdComponentsTest do
  # W259: sponsored_slot renders the redesign tokens, the same Sponsored pill
  # as sponsored_card, and an unchanged AdSlot hook contract.
  # async: false because these tests mutate the application-level :web_ads
  # config (same save/restore pattern as PostLive.ShowAdsTest).
  use ExUnit.Case, async: false

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import TraysSocialWeb.AdComponents

  setup do
    original_web_ads = Application.get_env(:trays_social, :web_ads, [])
    on_exit(fn -> Application.put_env(:trays_social, :web_ads, original_web_ads) end)
    :ok
  end

  defp put_web_ads(web_ads), do: Application.put_env(:trays_social, :web_ads, web_ads)

  defp assert_classes(html, classes) do
    for class <- classes, do: assert(html =~ class, "expected #{inspect(class)} in the markup")
  end

  defp render_slot do
    assigns = %{}

    rendered_to_string(~H"""
    <.sponsored_slot id="ad-slot-a" position="in-content-1" />
    """)
  end

  defp render_card do
    assigns = %{}

    rendered_to_string(~H"""
    <.sponsored_card slot={0} />
    """)
  end

  # The pill is the <span> whose text is exactly "Sponsored".
  defp pill_class(html) do
    [_, class] = Regex.run(~r/<span class="([^"]*)">\s*Sponsored\s*<\/span>/, html)
    class
  end

  describe "sponsored_slot/1" do
    test "renders the Sponsored label and house copy with redesign classes" do
      put_web_ads(script_url: nil, site_id: nil)
      html = render_slot()

      # The soft card container.
      assert html =~
               ~s|class="my-10 rounded-[21px] bg-base-100 p-1.5 text-base-content shadow-card"|

      # The unit surface the pill sits on, as on sponsored_card's photo.
      assert_classes(html, ["rounded-[15px] bg-cream-lift"])

      # House copy in the muted body tone.
      assert html =~
               ~r|<p class="max-w-\[420px\] text-sm leading-relaxed text-muted">\s*Trays stays free for home cooks|

      assert html =~ ~r|<p class="text-\[12px\] text-muted">\s*Nothing in this space tracks you.|
      assert html =~ "Sponsored"
    end

    test "uses the same Sponsored pill as sponsored_card" do
      put_web_ads(script_url: nil, site_id: nil)

      assert pill_class(render_slot()) == pill_class(render_card())
    end

    test "links Why this ad? to the ads-choices page" do
      put_web_ads(script_url: nil, site_id: nil)
      html = render_slot()

      assert html =~ ~r|<a[^>]*href="/privacy/ads-choices"[^>]*>\s*Why this ad\?\s*</a>|
    end

    test "renders no font-mono, rounded-sm or bg-base-200/40" do
      put_web_ads(script_url: nil, site_id: nil)
      html = render_slot()

      refute html =~ "font-mono"
      refute html =~ "rounded-sm"
      refute html =~ "bg-base-200/40"
    end

    test "keeps id, phx-hook AdSlot, phx-update ignore and the data attributes" do
      put_web_ads(script_url: "https://ads.example.com/loader.js", site_id: "trays-123")
      html = render_slot()

      assert html =~
               ~r|<div id="ad-slot-a" phx-hook="AdSlot" phx-update="ignore" data-script-url="https://ads.example.com/loader.js" data-site-id="trays-123"|

      assert html =~ ~s|data-ad-slot="in-content-1"|
      assert length(String.split(html, "data-ad-slot=")) - 1 == 1
      assert_classes(html, ["min-h-[250px]", "md:min-h-[280px]"])
    end

    test "reserves the full 250/280 px min-height for the creative" do
      put_web_ads(script_url: nil, site_id: nil)
      html = render_slot()

      [_, hook_class] = Regex.run(~r/<div id="ad-slot-a"[^>]* class="([^"]*)"/, html)
      classes = String.split(hook_class)

      assert "min-h-[250px]" in classes
      assert "md:min-h-[280px]" in classes

      # Vertical padding or a border inside the min-height would shrink the
      # reserved area, so a 250 px or 280 px unit would grow the slot (CLS).
      refute Enum.any?(classes, &String.match?(&1, ~r/^(md:|lg:)?(p|py|pt|pb)-|^border/))
    end

    test "keeps the Sponsored pill outside the hook element" do
      put_web_ads(script_url: nil, site_id: nil)
      html = render_slot()

      [_before_hook, hook_and_after] = String.split(html, ~s|id="ad-slot-a"|, parts: 2)
      refute hook_and_after =~ ~r/>\s*Sponsored\s*</
    end

    test "with no :web_ads config renders no data-script-url or data-site-id" do
      put_web_ads([])
      html = render_slot()

      assert html =~ ~s|phx-hook="AdSlot"|
      refute html =~ "data-script-url"
      refute html =~ "data-site-id"
    end
  end
end
