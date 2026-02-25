defmodule TraysSocialWeb.FeedLive.Index do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Posts

  on_mount {TraysSocialWeb.UserAuth, :mount_current_scope}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TraysSocial.PubSub, "posts:new")
      posts = Posts.list_posts()

      {:ok,
       socket
       |> assign(:page_title, "Feed")
       |> assign(:posts, posts)
       |> assign(:loading, false)}
    else
      {:ok,
       socket
       |> assign(:page_title, "Feed")
       |> assign(:posts, [])
       |> assign(:loading, true)}
    end
  end

  @impl true
  def handle_info({:new_post, post}, socket) do
    {:noreply, assign(socket, :posts, [post | socket.assigns.posts])}
  end
end
