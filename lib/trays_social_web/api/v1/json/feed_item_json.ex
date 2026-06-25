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

  This builds only the post branch; call `interleave_ads/2` to splice ad slots
  into the result at the configured density.
  """
  def render_list(posts, opts \\ %{}) do
    Enum.map(posts, &render_post(&1, opts))
  end

  @doc ~S"""
  W163: splice ad slots into an already-rendered list of `post` feed items at a
  density of one ad per `freq` posts.

  Density / placement rules (monetization design spec section 4.1):

    * One ad slot after every `freq` posts — never between every item.
    * No trailing ad: the slot goes *between* groups of `freq`, so a page that
      ends exactly on a group boundary has no ad tacked on the end.
    * Short pages (fewer than `freq` posts, e.g. the tail page) get no ad at all
      rather than being forced to carry one.

  Cursor stability is preserved by construction: this operates purely on the
  rendered item list and never touches the underlying post list the controller
  derives the cursor from. Each ad carries a 0-based `slot` index so the client
  can request/cache one ad creative per slot.
  """
  def interleave_ads(post_items, freq) when is_integer(freq) and freq > 0 do
    chunks = Enum.chunk_every(post_items, freq)
    last_index = length(chunks) - 1

    chunks
    |> Enum.with_index()
    |> Enum.flat_map(fn {chunk, index} ->
      if index < last_index, do: chunk ++ [render_ad(ad_slot(index))], else: chunk
    end)
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

  The server emits ad *slots* (a position + index), not ad creative — the iOS
  client fills each slot from the ad network (AdMob) on-device. See `ad_slot/1`
  for the slot payload `interleave_ads/2` produces.
  """
  def render_ad(ad) do
    %{type: "ad", ad: ad}
  end

  # The slot descriptor the server hands the client for one feed ad position.
  # Deliberately minimal: a stable 0-based index within the page plus the
  # surface, so the client knows where to render and can cache per slot. No ad
  # creative — that comes from the on-device ad network.
  defp ad_slot(index), do: %{slot: index, placement: "feed"}
end
