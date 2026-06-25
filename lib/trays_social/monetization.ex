defmodule TraysSocial.Monetization do
  @moduledoc """
  G38 monetization foundation — the single place that answers "should this
  user see ads?" and "is this monetization surface turned on?".

  NORTH STAR (non-negotiable): monetize AROUND the home-cooking experience,
  never the cooking itself. Nothing here gates, sells, or curates recipe
  CONTENT — these flags govern ad slots and the paid utility/ad-free tier.

  ## Feature flags

  Flags live under `config :trays_social, :features, [...]` (a keyword list)
  and default to **off**, so the whole monetization surface ships inert until
  a deploy explicitly enables a flag (config or the `FEATURES_*` runtime env
  overrides). Recognized flags:

    * `:in_app_ads`  — native ad slots in the iOS Feed/Find/Cook-Mode (W158)
    * `:web_ads`     — premium ad network on public web recipe pages (W159)
    * `:paid_tier`   — the ad-free + utility subscription (W160)

  ## Entitlement

  `is_subscriber` is the account-level entitlement set server-side only via
  `TraysSocial.Accounts.set_subscriber/2`. Subscribers never see ads.
  """

  alias TraysSocial.Accounts.User

  # How many posts between injected ad slots in the feed (W158/W163). Lives here
  # so the server is the single source of truth: it interleaves the ad slots
  # server-side at this density and also reports the value in ad_config. The
  # monetization design spec calls for ~1 commercial unit per screenful (~1 per
  # 8 items), never between every item.
  @ad_frequency 8

  @doc """
  Returns true when the named monetization feature flag is enabled.

  Unknown flags are treated as disabled. Only the literal `true` enables a
  flag — any other value is off.
  """
  @spec feature_enabled?(atom()) :: boolean()
  def feature_enabled?(feature) when is_atom(feature) do
    :trays_social
    |> Application.get_env(:features, [])
    |> Keyword.get(feature, false) == true
  end

  @doc "Whether the user currently holds the paid-tier entitlement."
  @spec subscriber?(User.t() | nil) :: boolean()
  def subscriber?(%User{is_subscriber: true}), do: true
  def subscriber?(_), do: false

  @doc """
  Whether in-app ads should be served to this user.

  True only when the `:in_app_ads` flag is on AND the user is not a
  subscriber. Subscribers (paid tier) are always ad-free.
  """
  @spec ads_enabled?(User.t() | nil) :: boolean()
  def ads_enabled?(user) do
    feature_enabled?(:in_app_ads) and not subscriber?(user)
  end

  @doc "Whether the public web recipe pages should render ad slots for this viewer."
  @spec web_ads_enabled?(User.t() | nil) :: boolean()
  def web_ads_enabled?(user) do
    feature_enabled?(:web_ads) and not subscriber?(user)
  end

  @doc "Whether the paid-tier purchase/paywall surface is enabled."
  @spec paid_tier_enabled?() :: boolean()
  def paid_tier_enabled?, do: feature_enabled?(:paid_tier)

  @doc "Posts between injected feed ad slots (W158)."
  @spec ad_frequency() :: pos_integer()
  def ad_frequency, do: @ad_frequency

  @doc """
  The ad-slot config block the API embeds in the feed response root so the
  iOS client knows whether and how often to inject ad slots.
  """
  @spec ad_config(User.t() | nil) :: %{enabled: boolean(), frequency: pos_integer()}
  def ad_config(user) do
    %{enabled: ads_enabled?(user), frequency: @ad_frequency}
  end
end
