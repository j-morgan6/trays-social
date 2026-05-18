defmodule TraysSocialWeb.FollowersLive.Show do
  @moduledoc """
  Followers / Following — tabbed list of cooks who follow `@username` or
  who `@username` follows. Reached from the profile counts.

  Routes: `/@:username/followers` and `/@:username/following`. The :tab
  assign comes from the route action and decides which list to load
  and which tab is active.
  """
  use TraysSocialWeb, :live_view

  alias TraysSocial.Accounts

  on_mount {TraysSocialWeb.UserAuth, :require_authenticated_user}
  on_mount {TraysSocialWeb.NotificationsHook, :mount_notifications}

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    case Accounts.get_user_by_username(username) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Cook not found")
         |> push_navigate(to: ~p"/")}

      user ->
        tab = socket.assigns.live_action
        {:ok, assign_for(socket, user, tab)}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  defp assign_for(socket, user, tab) do
    viewer = socket.assigns.current_scope && socket.assigns.current_scope.user

    cooks =
      case tab do
        :followers -> Accounts.list_followers(user.id, limit: 40)
        :following -> Accounts.list_following(user.id, limit: 40)
      end

    follower_count = Accounts.get_follower_count(user.id)
    following_count = Accounts.get_following_count(user.id)

    following_ids =
      if viewer do
        cooks
        |> Enum.filter(&Accounts.following?(viewer.id, &1.id))
        |> Enum.map(& &1.id)
        |> MapSet.new()
      else
        MapSet.new()
      end

    socket
    |> assign(:page_title, "@#{user.username} · #{Phoenix.Naming.humanize(tab)}")
    |> assign(:current_tab, :profile)
    |> assign(:user, user)
    |> assign(:tab, tab)
    |> assign(:cooks, cooks)
    |> assign(:query, "")
    |> assign(:follower_count, follower_count)
    |> assign(:following_count, following_count)
    |> assign(:following_ids, following_ids)
    |> assign(:viewer_id, viewer && viewer.id)
  end

  # Filter the loaded cooks by username or bio (case-insensitive substring).
  # The list is capped at ~40 in memory, so client-side filtering is fine
  # for now; if pagination expands this, fold the query into the DB.
  def filter_cooks(cooks, "") do
    cooks
  end

  def filter_cooks(cooks, query) do
    q = String.downcase(query)

    Enum.filter(cooks, fn cook ->
      String.contains?(String.downcase(cook.username), q) or
        (cook.bio && String.contains?(String.downcase(cook.bio), q))
    end)
  end

  @impl true
  def handle_event("search", %{"query" => q}, socket) do
    {:noreply, assign(socket, :query, q)}
  end

  @impl true
  def handle_event("toggle-follow", %{"id" => id_str}, socket) do
    target_id = String.to_integer(id_str)
    viewer = socket.assigns.current_scope.user

    case Enum.find(socket.assigns.cooks, &(&1.id == target_id)) do
      nil ->
        {:noreply, socket}

      target ->
        following = socket.assigns.following_ids

        new_following =
          if MapSet.member?(following, target.id) do
            Accounts.unfollow_user(viewer, target)
            MapSet.delete(following, target.id)
          else
            case Accounts.follow_user(viewer, target) do
              {:ok, _} -> MapSet.put(following, target.id)
              {:error, _} -> following
            end
          end

        {:noreply, assign(socket, :following_ids, new_following)}
    end
  end

  # First-week cooks earn a Mint Whisper "New cook" badge in the list,
  # matching the design's social proof for fresh accounts.
  def new_cook?(user) do
    case user.inserted_at do
      nil -> false
      ts -> DateTime.diff(DateTime.utc_now(), ts, :day) <= 7
    end
  end
end
