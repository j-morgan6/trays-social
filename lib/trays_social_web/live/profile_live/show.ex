defmodule TraysSocialWeb.ProfileLive.Show do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Accounts
  alias TraysSocial.Posts
  alias TraysSocialWeb.HomeFormatting

  on_mount {TraysSocialWeb.UserAuth, :require_authenticated_user}
  on_mount {TraysSocialWeb.UserAuth, :require_confirmed_user}
  on_mount {TraysSocialWeb.NotificationsHook, :mount_notifications}

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    case Accounts.get_user_by_username(username) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found")
         |> push_navigate(to: ~p"/feed")}

      user ->
        {:ok, mount_user_profile(socket, user)}
    end
  end

  @impl true
  def handle_event("toggle-follow", _params, socket) do
    case socket.assigns[:current_scope] do
      nil ->
        {:noreply, push_navigate(socket, to: ~p"/users/log-in")}

      %{user: current_user} ->
        {:noreply, toggle_follow(socket, current_user)}
    end
  end

  defp mount_user_profile(socket, user) do
    if connected?(socket) do
      posts = Posts.list_posts_by_user(user.id)
      {is_following, follower_count, following_count} = follow_stats(socket, user)

      socket
      |> assign_static(user)
      |> assign(:posts, posts)
      |> assign(:post_count, length(posts))
      |> assign(:is_following, is_following)
      |> assign(:follower_count, follower_count)
      |> assign(:following_count, following_count)
      |> assign(:loading, false)
    else
      socket
      |> assign_static(user)
      |> assign(:posts, [])
      |> assign(:post_count, 0)
      |> assign(:is_following, false)
      |> assign(:follower_count, 0)
      |> assign(:following_count, 0)
      |> assign(:loading, true)
    end
  end

  defp assign_static(socket, user) do
    socket
    |> assign(:page_title, "@#{user.username}")
    |> assign(:current_tab, :profile)
    |> assign(:recipe_first, TraysSocial.Features.recipe_first?())
    |> assign(:now, DateTime.utc_now())
    |> assign(:user, user)
  end

  defp follow_stats(socket, user) do
    case socket.assigns[:current_scope] do
      %{user: current_user} when current_user.id != user.id ->
        {
          Accounts.following?(current_user.id, user.id),
          Accounts.get_follower_count(user.id),
          Accounts.get_following_count(user.id)
        }

      _ ->
        {false, Accounts.get_follower_count(user.id), Accounts.get_following_count(user.id)}
    end
  end

  @doc false
  def format_count(n) when n >= 1_000_000 do
    formatted = Float.round(n / 1_000_000, 1)

    if formatted == trunc(formatted),
      do: "#{trunc(formatted)}M",
      else: "#{formatted}M"
  end

  def format_count(n) when n >= 1_000 do
    formatted = Float.round(n / 1_000, 1)

    if formatted == trunc(formatted),
      do: "#{trunc(formatted)}k",
      else: "#{formatted}k"
  end

  def format_count(n), do: "#{n}"

  # Recipe-first labels legacy photo posts and shows their caption; a
  # recipe shows the first sentence of its caption.
  defp photo_post?(post, recipe_first), do: recipe_first and post.type != "recipe"

  defp card_title(post, true), do: post.caption || ""
  defp card_title(post, false), do: TraysSocialWeb.TrayFormatting.post_title(post)

  defp own_profile?(%{current_scope: %{user: %{id: id}}, user: %{id: id}}), do: true
  defp own_profile?(_assigns), do: false

  defp toggle_follow(socket, current_user) do
    target_user = socket.assigns.user
    is_following = socket.assigns.is_following

    if is_following do
      Accounts.unfollow_user(current_user, target_user)

      socket
      |> assign(:is_following, false)
      |> update(:follower_count, &max(0, &1 - 1))
    else
      case Accounts.follow_user(current_user, target_user) do
        {:ok, _} ->
          socket
          |> assign(:is_following, true)
          |> update(:follower_count, &(&1 + 1))

        {:error, _} ->
          socket
      end
    end
  end
end
