defmodule TraysSocial.MonetizationTest do
  # Not async: these tests mutate the application-level :features config.
  use ExUnit.Case, async: false

  alias TraysSocial.Accounts.User
  alias TraysSocial.Monetization

  setup do
    original = Application.get_env(:trays_social, :features, [])
    on_exit(fn -> Application.put_env(:trays_social, :features, original) end)
    :ok
  end

  defp put_features(features), do: Application.put_env(:trays_social, :features, features)

  describe "feature_enabled?/1" do
    test "true only when the flag is literally true" do
      put_features(in_app_ads: true, web_ads: false, paid_tier: false)
      assert Monetization.feature_enabled?(:in_app_ads)
      refute Monetization.feature_enabled?(:web_ads)
      refute Monetization.feature_enabled?(:paid_tier)
    end

    test "unknown flags are disabled" do
      put_features([])
      refute Monetization.feature_enabled?(:nonexistent)
    end
  end

  describe "subscriber?/1" do
    test "true for a subscriber user, false otherwise" do
      assert Monetization.subscriber?(%User{is_subscriber: true})
      refute Monetization.subscriber?(%User{is_subscriber: false})
      refute Monetization.subscriber?(nil)
    end
  end

  describe "ads_enabled?/1" do
    test "false when the in_app_ads flag is off, regardless of subscription" do
      put_features(in_app_ads: false)
      refute Monetization.ads_enabled?(%User{is_subscriber: false})
    end

    test "true for a non-subscriber when the flag is on" do
      put_features(in_app_ads: true)
      assert Monetization.ads_enabled?(%User{is_subscriber: false})
    end

    test "always false for a subscriber even when the flag is on" do
      put_features(in_app_ads: true)
      refute Monetization.ads_enabled?(%User{is_subscriber: true})
    end
  end

  describe "web_ads_enabled?/1" do
    test "false when the web_ads flag is off" do
      put_features(web_ads: false)
      refute Monetization.web_ads_enabled?(%User{is_subscriber: false})
    end

    test "true for a non-subscriber when the flag is on" do
      put_features(web_ads: true)
      assert Monetization.web_ads_enabled?(%User{is_subscriber: false})
    end

    test "always false for a subscriber even when the flag is on" do
      put_features(web_ads: true)
      refute Monetization.web_ads_enabled?(%User{is_subscriber: true})
    end

    test "true for an unauthenticated (nil) viewer — anonymous web visitors see ads" do
      # Public recipe pages (W159) are viewable logged-out; an anonymous
      # viewer is not a subscriber, so they get ads when the flag is on.
      put_features(web_ads: true)
      assert Monetization.web_ads_enabled?(nil)
    end

    test "false for an anonymous viewer when the flag is off" do
      put_features(web_ads: false)
      refute Monetization.web_ads_enabled?(nil)
    end
  end

  describe "paid_tier_enabled?/0" do
    test "reflects the paid_tier flag" do
      put_features(paid_tier: true)
      assert Monetization.paid_tier_enabled?()

      put_features(paid_tier: false)
      refute Monetization.paid_tier_enabled?()
    end
  end

  describe "ad_config/1" do
    test "reports enabled state and the server-owned frequency" do
      put_features(in_app_ads: true)

      assert Monetization.ad_config(%User{is_subscriber: false}) ==
               %{enabled: true, frequency: Monetization.ad_frequency()}

      assert %{enabled: false} = Monetization.ad_config(%User{is_subscriber: true})
    end
  end
end
