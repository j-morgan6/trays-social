defmodule TraysSocialWeb.FeedLive.Index do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Posts

  on_mount {TraysSocialWeb.UserAuth, :mount_current_scope}

  @page_size 20

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TraysSocial.PubSub, "posts:new")
      Phoenix.PubSub.subscribe(TraysSocial.PubSub, "posts:likes")
      posts = Posts.list_posts(limit: @page_size)
      post_ids = Enum.map(posts, & &1.id)

      liked_post_ids =
        case socket.assigns[:current_scope] do
          %{user: user} -> Posts.liked_post_ids_for_user(user.id, post_ids)
          _ -> MapSet.new()
        end

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
       |> assign(:liked_post_ids, liked_post_ids)
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
       |> assign(:liked_post_ids, MapSet.new())
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

      new_post_ids = Enum.map(posts, & &1.id)

      new_liked_ids =
        case socket.assigns[:current_scope] do
          %{user: user} -> Posts.liked_post_ids_for_user(user.id, new_post_ids)
          _ -> MapSet.new()
        end

      socket =
        socket
        |> assign(:cursor, last_cursor(posts))
        |> assign(:has_more, length(posts) == @page_size)
        |> assign(:loading_more, false)
        |> update(:liked_post_ids, &MapSet.union(&1, new_liked_ids))
        |> update(:posts_map, &Map.merge(&1, Map.new(posts, fn p -> {p.id, p} end)))
        |> stream(:posts, posts, at: -1)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle-like", %{"post-id" => post_id_str}, socket) do
    case socket.assigns[:current_scope] do
      nil ->
        {:noreply, push_navigate(socket, to: ~p"/users/log-in")}

      %{user: user} ->
        post_id = String.to_integer(post_id_str)

        case Map.get(socket.assigns.posts_map, post_id) do
          nil ->
            {:noreply, socket}

          post ->
            liked = MapSet.member?(socket.assigns.liked_post_ids, post_id)

            # Optimistic update
            {new_count, new_liked_ids} =
              if liked do
                {max(0, post.like_count - 1), MapSet.delete(socket.assigns.liked_post_ids, post_id)}
              else
                {post.like_count + 1, MapSet.put(socket.assigns.liked_post_ids, post_id)}
              end

            updated_post = %{post | like_count: new_count}

            socket =
              socket
              |> assign(:liked_post_ids, new_liked_ids)
              |> update(:posts_map, &Map.put(&1, post_id, updated_post))
              |> stream_insert(:posts, updated_post)

            # Persist to DB and broadcast
            if liked do
              Posts.unlike_post(post, user)
            else
              Posts.like_post(post, user)
            end

            Phoenix.PubSub.broadcast(
              TraysSocial.PubSub,
              "posts:likes",
              {:like_updated, post_id, new_count}
            )

            {:noreply, socket}
        end
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

  @impl true
  def handle_info({:like_updated, post_id, like_count}, socket) do
    case Map.get(socket.assigns.posts_map, post_id) do
      nil ->
        {:noreply, socket}

      post ->
        updated_post = %{post | like_count: like_count}

        socket =
          socket
          |> update(:posts_map, &Map.put(&1, post_id, updated_post))
          |> stream_insert(:posts, updated_post)

        {:noreply, socket}
    end
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
