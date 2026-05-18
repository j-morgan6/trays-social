defmodule TraysSocialWeb.PostLive.Show do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Accounts
  alias TraysSocial.Posts

  on_mount {TraysSocialWeb.UserAuth, :mount_current_scope}
  on_mount {TraysSocialWeb.NotificationsHook, :mount_notifications}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    post = Posts.get_post!(id)
    comments = Posts.list_comments(post.id)

    viewer =
      case socket.assigns[:current_scope] do
        %{user: user} -> user
        _ -> nil
      end

    liked = viewer && Posts.liked_by?(post.id, viewer.id)
    bookmarked = viewer && Posts.bookmarked?(viewer.id, post.id)

    is_following =
      cond do
        viewer == nil -> false
        viewer.id == post.user_id -> false
        true -> Accounts.following?(viewer.id, post.user_id)
      end

    socket =
      socket
      |> assign(:page_title, "Post")
      |> assign(:post, post)
      |> assign(:photo_index, 0)
      |> assign(:liked, liked || false)
      |> assign(:bookmarked, bookmarked || false)
      |> assign(:is_following, is_following)
      |> assign(:checked_ingredient_ids, MapSet.new())
      |> assign(:cooking_started_at, nil)
      |> assign(:comment_body, "")
      |> stream(:comments, comments)

    {:ok, socket}
  end

  @impl true
  def handle_event("next-photo", _, socket) do
    post = socket.assigns.post
    count = photo_count(post)

    if count > 1 do
      next = rem(socket.assigns.photo_index + 1, count)
      {:noreply, assign(socket, :photo_index, next)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("prev-photo", _, socket) do
    post = socket.assigns.post
    count = photo_count(post)

    if count > 1 do
      prev = rem(socket.assigns.photo_index - 1 + count, count)
      {:noreply, assign(socket, :photo_index, prev)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle-like", _params, socket) do
    case socket.assigns[:current_scope] do
      nil ->
        {:noreply, push_navigate(socket, to: ~p"/users/log-in")}

      %{user: user} ->
        post = socket.assigns.post
        liked = socket.assigns.liked

        {new_count, new_liked} =
          if liked do
            {max(0, post.like_count - 1), false}
          else
            {post.like_count + 1, true}
          end

        updated_post = %{post | like_count: new_count}

        socket =
          socket
          |> assign(:liked, new_liked)
          |> assign(:post, updated_post)

        if liked do
          Posts.unlike_post(post, user)
        else
          Posts.like_post(post, user)
        end

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle-cook-mode", _params, socket) do
    new_started_at =
      if socket.assigns.cooking_started_at do
        # Reset the timer back to "not running" — also discards the
        # checked-ingredients state so the cook starts fresh next time.
        nil
      else
        DateTime.utc_now()
      end

    socket =
      socket
      |> assign(:cooking_started_at, new_started_at)
      |> assign(:checked_ingredient_ids,
        if(new_started_at, do: MapSet.new(), else: socket.assigns.checked_ingredient_ids)
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle-ingredient", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    set = socket.assigns.checked_ingredient_ids

    new_set =
      if MapSet.member?(set, id),
        do: MapSet.delete(set, id),
        else: MapSet.put(set, id)

    {:noreply, assign(socket, :checked_ingredient_ids, new_set)}
  end

  @impl true
  def handle_event("toggle-bookmark", _params, socket) do
    case socket.assigns[:current_scope] do
      nil ->
        {:noreply, push_navigate(socket, to: ~p"/users/log-in")}

      %{user: user} ->
        post = socket.assigns.post

        new_bookmarked =
          if socket.assigns.bookmarked do
            Posts.delete_bookmark(user.id, post.id)
            false
          else
            case Posts.create_bookmark(user.id, post.id) do
              {:ok, _} -> true
              {:error, _} -> socket.assigns.bookmarked
            end
          end

        {:noreply, assign(socket, :bookmarked, new_bookmarked)}
    end
  end

  @impl true
  def handle_event("toggle-follow", _params, socket) do
    case socket.assigns[:current_scope] do
      nil ->
        {:noreply, push_navigate(socket, to: ~p"/users/log-in")}

      %{user: viewer} ->
        author = socket.assigns.post.user

        # Guard: don't let users follow themselves through this affordance.
        if viewer.id == author.id do
          {:noreply, socket}
        else
          new_following =
            if socket.assigns.is_following do
              Accounts.unfollow_user(viewer, author)
              false
            else
              case Accounts.follow_user(viewer, author) do
                {:ok, _} -> true
                {:error, _} -> socket.assigns.is_following
              end
            end

          {:noreply, assign(socket, :is_following, new_following)}
        end
    end
  end

  @impl true
  def handle_event("update-comment-body", %{"value" => value}, socket) do
    {:noreply, assign(socket, :comment_body, value)}
  end

  @impl true
  def handle_event("add-comment", %{"comment" => %{"body" => body}}, socket) do
    case socket.assigns[:current_scope] do
      nil ->
        {:noreply, push_navigate(socket, to: ~p"/users/log-in")}

      %{user: user} ->
        post = socket.assigns.post

        case Posts.create_comment(post, user, %{body: body}) do
          {:ok, comment} ->
            updated_post = %{post | comment_count: post.comment_count + 1}

            socket =
              socket
              |> assign(:post, updated_post)
              |> assign(:comment_body, "")
              |> stream_insert(:comments, comment, at: -1)

            {:noreply, socket}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Could not add comment")}
        end
    end
  end

  @impl true
  def handle_event("delete-comment", %{"id" => id_str}, socket) do
    case socket.assigns[:current_scope] do
      nil ->
        {:noreply, socket}

      %{user: user} ->
        comment_id = String.to_integer(id_str)
        comment = Posts.get_comment!(comment_id)

        case Posts.delete_comment(comment, user) do
          {:ok, deleted_comment} ->
            post = socket.assigns.post
            updated_post = %{post | comment_count: max(0, post.comment_count - 1)}

            socket =
              socket
              |> assign(:post, updated_post)
              |> stream_delete(:comments, deleted_comment)

            {:noreply, socket}

          {:error, :unauthorized} ->
            {:noreply, put_flash(socket, :error, "Not authorized to delete this comment")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not delete comment")}
        end
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    post = socket.assigns.post

    # Verify user is the owner
    if socket.assigns.current_scope && socket.assigns.current_scope.user &&
         socket.assigns.current_scope.user.id == post.user_id do
      case Posts.delete_post(post) do
        {:ok, _post} ->
          {:noreply,
           socket
           |> put_flash(:info, "Post deleted successfully")
           |> push_navigate(to: ~p"/")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to delete post")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "You are not authorized to delete this post")}
    end
  end

  defp photo_count(post) do
    if Ecto.assoc_loaded?(post.post_photos) && !Enum.empty?(post.post_photos) do
      length(post.post_photos)
    else
      1
    end
  end

  # Render cook time as `2 hr 45 min` / `45 min` / `2 hr` so the metadata
  # strip on the recipe detail page can show editorial copy rather than
  # raw integers. Used by show.html.heex.
  def format_cook_time(minutes) when is_integer(minutes) and minutes > 0 do
    hours = div(minutes, 60)
    mins = rem(minutes, 60)

    case {hours, mins} do
      {0, m} -> "#{m} min"
      {h, 0} -> "#{h} hr"
      {h, m} -> "#{h} hr #{m} min"
    end
  end

  def format_cook_time(_), do: "—"
end
