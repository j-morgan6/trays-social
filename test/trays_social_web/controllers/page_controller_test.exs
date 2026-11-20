defmodule TraysSocialWeb.PageControllerTest do
  use TraysSocialWeb.ConnCase

  import TraysSocial.AccountsFixtures

  test "GET / renders the public landing page for anonymous visitors (W120)", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    # On-brand landing copy, not the Phoenix default template.
    assert html =~ "For home cooks"
    assert html =~ "recipe-sharing community"
    refute html =~ "mix phx.server"
  end

  # W211: the Plus section names a price and a trial only while paid_tier is
  # on. The flag is global app env, so restore it after every test (this
  # module is not async).
  describe "GET / Trays Plus section" do
    setup do
      original = Application.get_env(:trays_social, :features, [])
      on_exit(fn -> Application.put_env(:trays_social, :features, original) end)
      %{original: original}
    end

    test "with paid_tier on shows $3.99 and $29.99 (W182, W211)", %{
      conn: conn,
      original: original
    } do
      Application.put_env(:trays_social, :features, Keyword.put(original, :paid_tier, true))

      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "Trays Plus"
      # Price and trial must match App Store Connect exactly.
      assert html =~ "$3.99 per month or $29.99 per year"
      assert html =~ "7-day free trial"
      assert html =~ "Trays Plus is sold through the App Store"
      refute html =~ "coming in a future update"
      # A paid section has to reach the documents that govern the purchase.
      assert html =~ ~s|href="/terms"|
      assert html =~ ~s|href="/privacy"|
      # North star: Plus bundles utility, never recipe content.
      assert html =~ "Every recipe on Trays is free to read, cook, and save"
    end

    test "with paid_tier off shows 'coming soon' and no prices (W211)", %{
      conn: conn,
      original: original
    } do
      Application.put_env(:trays_social, :features, Keyword.delete(original, :paid_tier))

      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "Trays Plus is coming in a future update."
      assert html =~ "It is not available to buy yet."

      for phrase <- ["$3.99", "$29.99", "7-day", "free trial", "per month", "per year"] do
        refute html =~ phrase,
               "landing page must not show #{inspect(phrase)} while paid_tier is off"
      end

      refute html =~ "Trays Plus is sold through the App Store"
      # The recipes-stay-free framing stays whatever the flag says.
      assert html =~ "Recipes stay free."
      assert html =~ "Every recipe on Trays is free to read, cook, and save"
    end

    test "treats a paid_tier value other than literal true as off (W211)", %{
      conn: conn,
      original: original
    } do
      Application.put_env(:trays_social, :features, Keyword.put(original, :paid_tier, "true"))

      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "Trays Plus is coming in a future update."
      refute html =~ "$3.99"
    end
  end

  test "GET / no longer claims the feed has no ads (W182)", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    # The hero previously said posts land in feeds "with no ads and no
    # algorithm deciding what you see". The no-algorithm half is still true
    # and stays; the no-ads half is not, now that the ad slots exist.
    refute html =~ "no ads and no algorithm"
    assert html =~ "algorithm deciding what you see"
  end

  # W218: with recipe_first on the landing page describes Home, Search and My
  # Tray; with it off the Feed-era copy stays until production flips the flag.
  describe "GET / landing copy by recipe_first" do
    setup do
      original = Application.get_env(:trays_social, :features, [])
      on_exit(fn -> Application.put_env(:trays_social, :features, original) end)
      %{original: original}
    end

    test "with recipe_first on shows the recipe-first copy and no Feed card", %{
      conn: conn,
      original: original
    } do
      Application.put_env(:trays_social, :features, Keyword.put(original, :recipe_first, true))

      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "Find something to cook tonight."
      assert html =~ "search by the ingredients you already have"
      assert html =~ "Searching by ingredient is free."

      for title <- ["Home", "Search", "My Tray"] do
        assert html =~
                 ~s|<h2 class="font-display text-[19px] font-bold leading-tight">#{title}</h2>|
      end

      assert html =~ "Recipes are free. Plus adds a few tools."
      refute html =~ "Cook more."
      refute html =~ "For home cooks"
      # The page body drops the Feed card (the guest header is the layout's).
      refute html =~ "What the cooks you follow are making"
      # The redesign drops italic emphasis and mono uppercase eyebrows.
      refute html =~ "<em"
      refute html =~ "uppercase tracking-[0.18em]"
    end

    test "with recipe_first off keeps the original copy", %{conn: conn, original: original} do
      Application.put_env(:trays_social, :features, Keyword.delete(original, :recipe_first))

      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "Cook more."
      assert html =~ "recipe-sharing community"
      refute html =~ "Find something to cook tonight."
    end

    test "both versions link the App Store listing and have no placeholders or screenshots", %{
      conn: conn,
      original: original
    } do
      for on? <- [true, false] do
        Application.put_env(:trays_social, :features, Keyword.put(original, :recipe_first, on?))

        html = conn |> get(~p"/") |> html_response(200)

        assert html =~ ~s|href="https://apps.apple.com/app/id6762027510"|
        assert html =~ "Download on the App Store"
        refute html =~ "[App Store badge]"
        refute html =~ "[SCREENSHOT"
        refute html =~ "aspect-[9/19.5]"
      end
    end

    test "with recipe_first on, the Plus section still follows paid_tier", %{
      conn: conn,
      original: original
    } do
      Application.put_env(:trays_social, :features, Keyword.put(original, :recipe_first, true))
      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "Trays Plus is coming in a future update."
      assert html =~ "Trays Plus will be an optional subscription"
      refute html =~ "$3.99"

      Application.put_env(
        :trays_social,
        :features,
        original |> Keyword.put(:recipe_first, true) |> Keyword.put(:paid_tier, true)
      )

      html = conn |> get(~p"/") |> html_response(200)

      assert html =~ "$3.99 per month or $29.99 per year"
      assert html =~ "Trays Plus is an optional subscription"
      refute html =~ "Trays Plus is coming in a future update."
    end
  end

  test "GET / redirects authenticated visitors to the feed (W120)", %{conn: conn} do
    user = user_fixture()

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/")

    assert redirected_to(conn) == ~p"/feed"
  end
end
