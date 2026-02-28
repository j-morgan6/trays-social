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
       |> assign(:photo_indices, %{})
       |> assign(:loading, false)}
    else
      {:ok,
       socket
       |> assign(:page_title, "Feed")
       |> assign(:posts, [])
       |> assign(:selected_post_id, nil)
       |> assign(:photo_indices, %{})
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
  def handle_event("next-photo", %{"post-id" => post_id_str}, socket) do
    post_id = String.to_integer(post_id_str)
    post = Enum.find(socket.assigns.posts, &(&1.id == post_id))
    count = length(post.post_photos)

    if count > 1 do
      current = Map.get(socket.assigns.photo_indices, post_id, 0)
      next = rem(current + 1, count)
      {:noreply, assign(socket, :photo_indices, Map.put(socket.assigns.photo_indices, post_id, next))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("prev-photo", %{"post-id" => post_id_str}, socket) do
    post_id = String.to_integer(post_id_str)
    post = Enum.find(socket.assigns.posts, &(&1.id == post_id))
    count = length(post.post_photos)

    if count > 1 do
      current = Map.get(socket.assigns.photo_indices, post_id, 0)
      prev = rem(current - 1 + count, count)
      {:noreply, assign(socket, :photo_indices, Map.put(socket.assigns.photo_indices, post_id, prev))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:new_post, post}, socket) do
    full_post = Posts.get_post!(post.id)
    {:noreply, assign(socket, :posts, [full_post | socket.assigns.posts])}
  end
end
