defmodule TraysSocialWeb.API.V1.JSON.FeedItemJSON do
  @moduledoc """
  G38/W162: discriminated-union ("tagged") rendering for the `/api/v1/feed`
  data array. Each element is `%{type: "post" | "ad", <payload>}` — a tagged
  union, NOT a flag on `Post`.

  Why a union and not an `is_ad` flag on the post: a native ad is third-party
  content, not user content, and conflating the two forecloses the future
  "promoted post" product (see the monetization design spec, section 4.3).
  A flat discriminator is also impossible here — `Post.type` already exists
  and is validated as `~w(recipe post)`, so a post's own content-type can
  literally be the string `"post"`, which would alias the union discriminator.
  The payload is therefore nested under a `:post` / `:ad` key.

  ## Wire-shape gating (important)

  This renderer is only used by the controller when ads are actually being
  served to the viewer (`TraysSocial.Monetization.ads_enabled?/1`). While the
  `:in_app_ads` flag is off — its default — the controller keeps emitting the
  legacy flat `PostJSON` list, byte-identical to before this module existed,
  so the shipped iOS client (which decodes `data` as `[Post]` with a strict
  schema) is unaffected. Clients learn which shape to expect from
  `ad_config.enabled` in the same response.

  Ad *insertion* (cadence / density) is W163's job; this module provides the
  post branch and the ad stub so both arms of the union exist.
  """

  alias TraysSocialWeb.API.V1.JSON.PostJSON

  @doc """
  Render a list of posts as tagged `post` feed items.

  Ad items are interleaved by the controller (W163), not here — this builds
  the post branch of the union from the real-post list.
  """
  def render_list(posts, opts \\ %{}) do
    Enum.map(posts, &render_post(&1, opts))
  end

  @doc ~S"""
  Wrap a single post as a tagged feed item: `%{type: "post", post: <PostJSON>}`.

  The post payload is exactly `PostJSON.render/2`, so post items retain every
  field they have today — only nested one level under `:post`.
  """
  def render_post(post, opts \\ %{}) do
    %{type: "post", post: PostJSON.render(post, opts)}
  end

  @doc ~S"""
  Wrap an ad payload as a tagged feed item: `%{type: "ad", ad: <ad>}`.

  Stub for the ad branch of the union — W163 supplies real ad payloads and the
  insertion cadence. Kept here so the union has both arms and the iOS union
  model can be built against a stable shape.
  """
  def render_ad(ad) do
    %{type: "ad", ad: ad}
  end
end
