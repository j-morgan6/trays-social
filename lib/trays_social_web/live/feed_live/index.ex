defmodule TraysSocialWeb.FeedLive.Index do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Posts

  on_mount {TraysSocialWeb.UserAuth, :mount_current_scope}

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to new post notifications
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TraysSocial.PubSub, "posts:new")
    end

    posts = Posts.list_posts()

    socket =
      socket
      |> assign(:page_title, "Feed")
      |> assign(:posts, posts)

    {:ok, socket}
  end

  @impl true
  def handle_info({:new_post, post}, socket) do
    # Prepend new post to the feed
    posts = [post | socket.assigns.posts]

    {:noreply, assign(socket, :posts, posts)}
  end
end
