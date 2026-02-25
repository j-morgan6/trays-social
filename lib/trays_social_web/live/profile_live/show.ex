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

          {:ok,
           socket
           |> assign(:page_title, "@#{user.username}")
           |> assign(:user, user)
           |> assign(:posts, posts)
           |> assign(:post_count, length(posts))
           |> assign(:loading, false)}
        else
          {:ok,
           socket
           |> assign(:page_title, "@#{user.username}")
           |> assign(:user, user)
           |> assign(:posts, [])
           |> assign(:post_count, 0)
           |> assign(:loading, true)}
        end
    end
  end
end
