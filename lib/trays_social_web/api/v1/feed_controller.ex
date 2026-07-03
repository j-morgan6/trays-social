defmodule TraysSocialWeb.API.V1.FeedController do
  use TraysSocialWeb, :controller

  alias TraysSocial.Accounts
  alias TraysSocial.Monetization
  alias TraysSocial.Posts
  alias TraysSocialWeb.API.V1.JSON.FeedItemJSON
  alias TraysSocialWeb.API.V1.JSON.PostJSON

  @page_size 20

  def index(conn, params) do
    user = conn.assigns.current_user
    {cursor_id, cursor_time} = decode_cursor(params["cursor"])

    # W167: both-direction exclusion — users you blocked AND users who blocked you.
    blocked_ids = Accounts.blocked_pair_ids(user.id)
    muted_keywords = Accounts.get_muted_keywords(user.id)

    posts =
      Posts.list_posts(
        for_user_id: user.id,
        limit: @page_size,
        cursor_id: cursor_id,
        cursor_time: cursor_time,
        blocked_user_ids: blocked_ids,
        muted_keywords: muted_keywords
      )

    post_ids = Enum.map(posts, & &1.id)
    liked_post_ids = Posts.liked_post_ids_for_user(user.id, post_ids)
    bookmarked_post_ids = Posts.bookmarked_post_ids_for_user(user.id, post_ids)
    # G38/W162: the cursor is computed from the last REAL post and never from an
    # ad item, so paging is unaffected by the discriminated-union shape below.
    next_cursor = encode_cursor(List.last(posts))

    render_opts = %{liked_post_ids: liked_post_ids, bookmarked_post_ids: bookmarked_post_ids}

    json(conn, %{
      data: render_feed_data(posts, render_opts, user),
      cursor: next_cursor,
      # G38/W158: tells the iOS client whether to inject native ad slots and
      # how often. `enabled` is false while the :in_app_ads flag is off and
      # always false for subscribers, so this ships inert until launch.
      ad_config: Monetization.ad_config(user)
    })
  end

  # G38/W162: switch the `data` wire shape based on whether ads are actually
  # served to this viewer.
  #
  # * ads served (`:in_app_ads` on AND not a subscriber) -> tagged FeedItem
  #   union (`%{type: "post", post: ...}`), the shape ad insertion (W163)
  #   needs.
  # * otherwise (the default everywhere today) -> legacy flat PostJSON list,
  #   byte-identical to before W162, so the shipped iOS client that decodes
  #   `data` as `[Post]` keeps working. Clients key off `ad_config.enabled`
  #   (which equals this same predicate) to know which shape to expect.
  defp render_feed_data(posts, render_opts, user) do
    if Monetization.ads_enabled?(user) do
      # W163: interleave ad slots into the union at ~1 per ad_frequency posts.
      # interleave_ads/2 operates only on the rendered items, so the cursor
      # (derived from `posts` above) is unaffected.
      posts
      |> FeedItemJSON.render_list(render_opts)
      |> FeedItemJSON.interleave_ads(Monetization.ad_frequency())
    else
      PostJSON.render_list(posts, render_opts)
    end
  end

  defp decode_cursor(nil), do: {nil, nil}

  defp decode_cursor(cursor) do
    case Base.url_decode64(cursor, padding: false) do
      {:ok, decoded} ->
        case String.split(decoded, ":", parts: 2) do
          [id_str, time_str] ->
            {String.to_integer(id_str), DateTime.from_iso8601(time_str) |> elem(1)}

          _ ->
            {nil, nil}
        end

      :error ->
        {nil, nil}
    end
  rescue
    _ -> {nil, nil}
  end

  defp encode_cursor(nil), do: nil

  defp encode_cursor(post) do
    Base.url_encode64("#{post.id}:#{DateTime.to_iso8601(post.inserted_at)}", padding: false)
  end
end
