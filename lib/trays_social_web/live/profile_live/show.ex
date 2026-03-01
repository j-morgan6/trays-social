defmodule TraysSocialWeb.ProfileLive.Show do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Accounts
  alias TraysSocial.Posts

  on_mount {TraysSocialWeb.UserAuth, :mount_current_scope}

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    case Accounts.get_user_by_username(username) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found")
         |> push_navigate(to: ~p"/")}

      user ->
        if connected?(socket) do
          posts = Posts.list_posts_by_user(user.id)

          {is_following, follower_count, following_count} =
            case socket.assigns[:current_scope] do
              %{user: current_user} when current_user.id != user.id ->
                {
                  Accounts.following?(current_user.id, user.id),
                  Accounts.get_follower_count(user.id),
                  Accounts.get_following_count(user.id)
                }

              _ ->
                {
                  false,
                  Accounts.get_follower_count(user.id),
                  Accounts.get_following_count(user.id)
                }
            end

          {:ok,
           socket
           |> assign(:page_title, "@#{user.username}")
           |> assign(:current_tab, :profile)
           |> assign(:user, user)
           |> assign(:posts, posts)
           |> assign(:post_count, length(posts))
           |> assign(:is_following, is_following)
           |> assign(:follower_count, follower_count)
           |> assign(:following_count, following_count)
           |> assign(:loading, false)}
        else
          {:ok,
           socket
           |> assign(:page_title, "@#{user.username}")
           |> assign(:current_tab, :profile)
           |> assign(:user, user)
           |> assign(:posts, [])
           |> assign(:post_count, 0)
           |> assign(:is_following, false)
           |> assign(:follower_count, 0)
           |> assign(:following_count, 0)
           |> assign(:loading, true)}
        end
    end
  end

  @impl true
  def handle_event("toggle-follow", _params, socket) do
    case socket.assigns[:current_scope] do
      nil ->
        {:noreply, push_navigate(socket, to: ~p"/users/log-in")}

      %{user: current_user} ->
        target_user = socket.assigns.user
        is_following = socket.assigns.is_following

        if is_following do
          Accounts.unfollow_user(current_user, target_user)

          {:noreply,
           socket
           |> assign(:is_following, false)
           |> update(:follower_count, &max(0, &1 - 1))}
        else
          case Accounts.follow_user(current_user, target_user) do
            {:ok, _} ->
              {:noreply,
               socket
               |> assign(:is_following, true)
               |> update(:follower_count, &(&1 + 1))}

            {:error, _} ->
              {:noreply, socket}
          end
        end
    end
  end
end
