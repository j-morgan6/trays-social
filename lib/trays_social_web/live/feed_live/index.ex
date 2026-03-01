defmodule TraysSocialWeb.FeedLive.Index do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Posts

  on_mount {TraysSocialWeb.UserAuth, :mount_current_scope}

  @page_size 20

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TraysSocial.PubSub, "posts:new")
      posts = Posts.list_posts(limit: @page_size)

      {:ok,
       socket
       |> assign(:page_title, "Feed")
       |> assign(:current_tab, :feed)
       |> assign(:selected_post_id, nil)
       |> assign(:photo_indices, %{})
       |> assign(:loading, false)
       |> assign(:loading_more, false)
       |> assign(:has_more, length(posts) == @page_size)
       |> assign(:no_posts, Enum.empty?(posts))
       |> assign(:cursor, last_cursor(posts))
       |> assign(:posts_map, Map.new(posts, &{&1.id, &1}))
       |> stream(:posts, posts)}
    else
      {:ok,
       socket
       |> assign(:page_title, "Feed")
       |> assign(:current_tab, :feed)
       |> assign(:selected_post_id, nil)
       |> assign(:photo_indices, %{})
       |> assign(:loading, true)
       |> assign(:loading_more, false)
       |> assign(:has_more, true)
       |> assign(:no_posts, false)
       |> assign(:cursor, nil)
       |> assign(:posts_map, %{})
       |> stream(:posts, [])}
    end
  end

  @impl true
  def handle_event("load-more", _, socket) do
    if socket.assigns.has_more && !socket.assigns.loading_more && socket.assigns.cursor do
      {cursor_id, cursor_time} = socket.assigns.cursor

      posts =
        Posts.list_posts(
          limit: @page_size,
          cursor_id: cursor_id,
          cursor_time: cursor_time
        )

      socket =
        socket
        |> assign(:cursor, last_cursor(posts))
        |> assign(:has_more, length(posts) == @page_size)
        |> assign(:loading_more, false)
        |> update(:posts_map, &Map.merge(&1, Map.new(posts, fn p -> {p.id, p} end)))
        |> stream(:posts, posts, at: -1)

      {:noreply, socket}
    else
      {:noreply, socket}
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

    case Map.get(socket.assigns.posts_map, post_id) do
      nil ->
        {:noreply, socket}

      post ->
        count = photo_count(post)

        if count > 1 do
          current = Map.get(socket.assigns.photo_indices, post_id, 0)
          next = rem(current + 1, count)
          {:noreply, assign(socket, :photo_indices, Map.put(socket.assigns.photo_indices, post_id, next))}
        else
          {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("prev-photo", %{"post-id" => post_id_str}, socket) do
    post_id = String.to_integer(post_id_str)

    case Map.get(socket.assigns.posts_map, post_id) do
      nil ->
        {:noreply, socket}

      post ->
        count = photo_count(post)

        if count > 1 do
          current = Map.get(socket.assigns.photo_indices, post_id, 0)
          prev = rem(current - 1 + count, count)
          {:noreply, assign(socket, :photo_indices, Map.put(socket.assigns.photo_indices, post_id, prev))}
        else
          {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_info({:new_post, post}, socket) do
    full_post = Posts.get_post!(post.id)

    socket =
      socket
      |> assign(:no_posts, false)
      |> update(:posts_map, &Map.put(&1, full_post.id, full_post))
      |> stream_insert(:posts, full_post, at: 0)

    {:noreply, socket}
  end

  defp last_cursor([]), do: nil

  defp last_cursor(posts) do
    last = List.last(posts)
    {last.id, last.inserted_at}
  end

  defp photo_count(post) do
    if Ecto.assoc_loaded?(post.post_photos) && !Enum.empty?(post.post_photos),
      do: length(post.post_photos),
      else: 1
  end
end
