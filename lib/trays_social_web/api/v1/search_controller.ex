defmodule TraysSocialWeb.API.V1.SearchController do
  use TraysSocialWeb, :controller

  alias TraysSocial.Accounts
  alias TraysSocial.Monetization
  alias TraysSocial.Posts
  alias TraysSocial.Posts.BrowseCategories
  alias TraysSocial.Posts.IngredientSearch
  alias TraysSocialWeb.API.V1.JSON.FeedItemJSON
  alias TraysSocialWeb.API.V1.JSON.IngredientSearchJSON
  alias TraysSocialWeb.API.V1.JSON.PostJSON

  # index/2 always returns a conn, so the fallback only ever sees
  # ingredients/2's {:error, :invalid_ingredients}.
  action_fallback TraysSocialWeb.API.V1.FallbackController

  @max_query_length 100
  @max_tag_length 50
  @group_preview 5
  @page_size 20

  # Recipe-first search. `grouped=true` returns the viewer's tray, people they
  # follow and everyone else in one response; `group=...` pages one of those
  # groups. Without either, the legacy response is returned unchanged.
  def index(conn, params) do
    cond do
      params["grouped"] == "true" -> grouped(conn, params)
      params["group"] in ~w(tray following everyone) -> single_group(conn, params)
      true -> legacy_index(conn, params)
    end
  end

  # GET /api/v1/search/browse: the fixed Browse tiles plus the Most saved rail.
  def browse(conn, _params) do
    user = conn.assigns.current_user

    posts =
      Posts.list_most_saved_posts(@page_size,
        blocked_user_ids: Accounts.blocked_pair_ids(user.id)
      )

    json(conn, %{
      data: %{
        categories: Enum.map(BrowseCategories.list(), &BrowseCategories.to_json/1),
        most_saved: render_items(posts, render_opts(user, posts), user, true)
      },
      ad_config: Monetization.ad_config(user)
    })
  end

  # Pre-recipe-first search. Kept byte-for-byte for older app builds.
  defp legacy_index(conn, params) do
    user = conn.assigns.current_user
    query = sanitize(params["q"], @max_query_length) || ""
    max_cooking_time = parse_int(params["max_cooking_time"])
    tag = sanitize(params["tag"], @max_tag_length)
    blocked_ids = Accounts.blocked_pair_ids(user.id)
    {cursor_id, cursor_time} = decode_cursor(params["cursor"])

    posts =
      Posts.search_posts(query,
        limit: 20,
        max_cooking_time: max_cooking_time,
        tag: tag,
        blocked_user_ids: blocked_ids,
        cursor_id: cursor_id,
        cursor_time: cursor_time
      )

    users =
      if tag || max_cooking_time do
        []
      else
        Accounts.search_users(query, limit: 10, blocked_user_ids: blocked_ids)
      end

    json(conn, %{
      data: %{
        posts: render_legacy_posts(posts, user),
        users: Enum.map(users, &render_user/1)
      },
      cursor: encode_cursor(List.last(posts))
    })
  end

  defp render_legacy_posts(posts, user) do
    post_ids = Enum.map(posts, & &1.id)
    liked_post_ids = Posts.liked_post_ids_for_user(user.id, post_ids)
    bookmarked_post_ids = Posts.bookmarked_post_ids_for_user(user.id, post_ids)

    PostJSON.render_list(posts, %{
      liked_post_ids: liked_post_ids,
      bookmarked_post_ids: bookmarked_post_ids
    })
  end

  # Recipe-first "What I have": GET /api/v1/search/ingredients?have[]=...
  # Ranking, grouping and the result cap live in IngredientSearch; this action
  # only validates the chips, supplies the viewer's block and follow sets, and
  # renders. Invalid chips fall through to the FallbackController as a 422.
  def ingredients(conn, params) do
    user = conn.assigns.current_user

    with {:ok, terms} <- IngredientSearch.normalize_terms(params["have"]) do
      results =
        Posts.search_by_ingredients(user.id, terms,
          blocked_user_ids: Accounts.blocked_pair_ids(user.id),
          following_ids: Accounts.list_following_ids(user.id)
        )

      post_ids = Enum.map(results.everything ++ results.almost, & &1.post.id)

      render_opts = %{
        liked_post_ids: Posts.liked_post_ids_for_user(user.id, post_ids),
        bookmarked_post_ids: Posts.bookmarked_post_ids_for_user(user.id, post_ids)
      }

      json(conn, %{data: IngredientSearchJSON.render(results, render_opts)})
    end
  end

  defp grouped(conn, params) do
    user = conn.assigns.current_user
    terms = search_terms(params)
    blocked_ids = Accounts.blocked_pair_ids(user.id)

    %{tray: tray, following: following, everyone: everyone} =
      Posts.search_grouped(user.id, terms.query,
        following_ids: Accounts.list_following_ids(user.id),
        blocked_user_ids: blocked_ids,
        max_cooking_time: terms.max_cooking_time,
        tag: terms.tag,
        preview_limit: @group_preview,
        limit: @page_size
      )

    users =
      if terms.tag || terms.max_cooking_time,
        do: [],
        else: Accounts.search_users(terms.query, limit: 10, blocked_user_ids: blocked_ids)

    opts = render_opts(user, tray ++ following ++ everyone)

    json(conn, %{
      data: %{
        users: Enum.map(users, &render_user/1),
        tray: PostJSON.render_list(tray, opts),
        following: PostJSON.render_list(following, opts),
        everyone: render_items(everyone, opts, user, true)
      },
      cursor: encode_cursor(List.last(everyone)),
      ad_config: Monetization.ad_config(user)
    })
  end

  defp single_group(conn, params) do
    user = conn.assigns.current_user
    terms = search_terms(params)
    {cursor_id, cursor_time} = decode_cursor(params["cursor"])

    posts =
      Posts.search_posts(
        terms.query,
        limit: @page_size,
        group: search_group(params["group"], user.id),
        cursor_id: cursor_id,
        cursor_time: cursor_time,
        max_cooking_time: terms.max_cooking_time,
        tag: terms.tag,
        blocked_user_ids: Accounts.blocked_pair_ids(user.id),
        recipes_only: true
      )

    ads_allowed? = params["group"] == "everyone"

    json(conn, %{
      data: %{posts: render_items(posts, render_opts(user, posts), user, ads_allowed?)},
      cursor: encode_cursor(List.last(posts)),
      ad_config: Monetization.ad_config(user)
    })
  end

  defp search_group("tray", user_id), do: {:tray, user_id}

  defp search_group("following", user_id),
    do: {:following, user_id, Accounts.list_following_ids(user_id)}

  defp search_group("everyone", user_id),
    do: {:everyone, user_id, Accounts.list_following_ids(user_id)}

  # A `category` key is only looked up in the fixed BrowseCategories list; an
  # unknown key yields nil and contributes nothing. Explicit params win over the
  # category's saved query.
  defp search_terms(params) do
    category = BrowseCategories.fetch(params["category"]) || %{}

    %{
      query: sanitize(params["q"], @max_query_length) || category[:q] || "",
      max_cooking_time: parse_int(params["max_cooking_time"]) || category[:max_cooking_time],
      tag: sanitize(params["tag"], @max_tag_length) || category[:tag]
    }
  end

  defp render_opts(user, posts) do
    ids = Enum.map(posts, & &1.id)

    %{
      liked_post_ids: Posts.liked_post_ids_for_user(user.id, ids),
      bookmarked_post_ids: Posts.bookmarked_post_ids_for_user(user.id, ids)
    }
  end

  # Always FeedItem-shaped so clients decode one type; ads only where allowed
  # (everyone and Most saved, never tray or following).
  defp render_items(posts, opts, user, ads_allowed?) do
    items = FeedItemJSON.render_list(posts, opts)

    if ads_allowed? and Monetization.ads_enabled?(user) do
      FeedItemJSON.interleave_ads(items, Monetization.ad_frequency(), "find")
    else
      items
    end
  end

  # D107: strict decode — malformed input degrades to page 1 instead of
  # leaking Ecto.Query.CastError / DBConnection.EncodeError as 500s (the
  # elem(1)-on-error-tuple hazard flagged in the 2026-07-02 review).
  defp decode_cursor(nil), do: {nil, nil}

  defp decode_cursor(cursor) when is_binary(cursor) do
    with {:ok, decoded} <- Base.url_decode64(cursor, padding: false),
         [id_str, time_str] <- String.split(decoded, ":", parts: 2),
         {id, ""} when id > 0 and id < 9_223_372_036_854_775_807 <- Integer.parse(id_str),
         {:ok, time, _offset} <- DateTime.from_iso8601(time_str) do
      {id, time}
    else
      _ -> {nil, nil}
    end
  end

  defp decode_cursor(_), do: {nil, nil}

  defp encode_cursor(nil), do: nil

  defp encode_cursor(post) do
    Base.url_encode64("#{post.id}:#{DateTime.to_iso8601(post.inserted_at)}", padding: false)
  end

  defp render_user(user) do
    %{
      id: user.id,
      username: user.username,
      bio: user.bio,
      profile_photo_url: user.profile_photo_url
    }
  end

  defp parse_int(nil), do: nil

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(_), do: nil

  defp sanitize(nil, _max), do: nil

  defp sanitize(value, max) when is_binary(value) do
    case value |> String.trim() |> String.slice(0, max) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp sanitize(_, _), do: nil
end
