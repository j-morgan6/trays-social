defmodule TraysSocialWeb.API.V1.PostController do
  use TraysSocialWeb, :controller

  action_fallback TraysSocialWeb.API.V1.FallbackController

  alias TraysSocial.Monetization
  alias TraysSocial.Posts
  alias TraysSocialWeb.API.V1.JSON.FeedItemJSON
  alias TraysSocialWeb.API.V1.JSON.PostJSON

  def trending(conn, _params) do
    user = conn.assigns.current_user
    blocked_ids = TraysSocial.Accounts.blocked_pair_ids(user.id)
    posts = Posts.list_trending_posts(20, blocked_user_ids: blocked_ids)
    post_ids = Enum.map(posts, & &1.id)
    liked_post_ids = Posts.liked_post_ids_for_user(user.id, post_ids)
    bookmarked_post_ids = Posts.bookmarked_post_ids_for_user(user.id, post_ids)

    render_opts = %{liked_post_ids: liked_post_ids, bookmarked_post_ids: bookmarked_post_ids}

    json(conn, %{
      data: render_trending_data(posts, render_opts, user),
      # G38/W158: same contract as /api/v1/feed — tells the iOS client whether
      # ad slots are being served on this surface and at what cadence.
      ad_config: Monetization.ad_config(user)
    })
  end

  # G38/W158: Find-tab twin of FeedController.render_feed_data/3 (kept
  # deliberately duplicated — two call sites don't justify a shared module).
  #
  # * ads served (`:in_app_ads` on AND not a subscriber) -> tagged FeedItem
  #   union with ad slots interleaved at ad_frequency, placement "find".
  # * otherwise (the default everywhere today) -> legacy flat PostJSON list,
  #   byte-identical to before this change, so the shipped iOS client that
  #   decodes `data` as `[Post]` keeps working. Clients key off
  #   `ad_config.enabled` to know which shape to expect.
  defp render_trending_data(posts, render_opts, user) do
    if Monetization.ads_enabled?(user) do
      posts
      |> FeedItemJSON.render_list(render_opts)
      |> FeedItemJSON.interleave_ads(Monetization.ad_frequency(), "find")
    else
      PostJSON.render_list(posts, render_opts)
    end
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    try do
      post = Posts.get_post!(id)

      # W167: a direct post link is still invisible across a block, in either
      # direction. 404 (not 403) so blocks aren't enumerable.
      if TraysSocial.Accounts.blocked_between?(user.id, post.user_id) do
        throw(:blocked_not_found)
      end

      liked_post_ids = Posts.liked_post_ids_for_user(user.id, [post.id])
      bookmarked_post_ids = Posts.bookmarked_post_ids_for_user(user.id, [post.id])

      json(conn, %{
        data:
          PostJSON.render(post, %{
            liked_post_ids: liked_post_ids,
            bookmarked_post_ids: bookmarked_post_ids
          })
      })
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
      Ecto.Query.CastError -> {:error, :not_found}
    catch
      :blocked_not_found -> {:error, :not_found}
    end
  end

  def create(conn, params) do
    user = conn.assigns.current_user
    # D44: user_id is passed positionally to Posts.create_post; it is NOT
    # mixed into the attrs map. Even a client request body claiming
    # `{"user_id": <victim>}` gets dropped because Post.changeset has the
    # field stripped from its cast list.
    attrs = Map.drop(params, ["user_id"])

    case Posts.create_post(user.id, attrs) do
      {:ok, post} ->
        post = Posts.get_post!(post.id)

        conn
        |> put_status(:created)
        |> json(%{data: PostJSON.render(post)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    try do
      post = Posts.get_post!(id)

      if post.user_id != user.id do
        {:error, :forbidden}
      else
        # W147 scope: text + photo only. Allowlist the four editable fields so
        # a client cannot switch :type (castable in Post.changeset) and so
        # :user_id stays immutable (also stripped from the cast list, D44).
        # Nested associations (ingredients/steps/tools/tags) are out of scope.
        # update_post_details/2 also syncs the position-0 post_photos row the
        # client actually renders — a plain photo_url write would not surface.
        attrs = Map.take(params, ["caption", "cooking_time_minutes", "servings", "photo_url"])

        case Posts.update_post_details(post, attrs) do
          {:ok, updated} ->
            # Re-fetch for preloaded associations; Repo.update returns them bare.
            updated = Posts.get_post!(updated.id)
            json(conn, %{data: PostJSON.render(updated)})

          {:error, changeset} ->
            {:error, changeset}
        end
      end
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
      Ecto.Query.CastError -> {:error, :not_found}
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    try do
      post = Posts.get_post!(id)

      if post.user_id != user.id do
        {:error, :forbidden}
      else
        case Posts.delete_post(post) do
          {:ok, _} -> json(conn, %{data: %{message: "post deleted"}})
          {:error, changeset} -> {:error, changeset}
        end
      end
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
      Ecto.Query.CastError -> {:error, :not_found}
    end
  end
end
