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
       |> assign(:selected_post_id, nil)
       |> assign(:loading, false)}
    else
      {:ok,
       socket
       |> assign(:page_title, "Feed")
       |> assign(:posts, [])
       |> assign(:selected_post_id, nil)
       |> assign(:loading, true)}
    end
  end

  @impl true
  def handle_event("open-drawer", %{"id" => post_id_str}, socket) do
    {:noreply, assign(socket, :selected_post_id, String.to_integer(post_id_str))}
  end

  @impl true
  def handle_event("close-drawer", _, socket) do
    {:noreply, assign(socket, :selected_post_id, nil)}
  end

  @impl true
  def handle_info({:new_post, post}, socket) do
    full_post = Posts.get_post!(post.id)
    {:noreply, assign(socket, :posts, [full_post | socket.assigns.posts])}
  end
end
