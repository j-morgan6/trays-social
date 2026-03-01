defmodule TraysSocialWeb.PostLive.Show do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Posts

  on_mount {TraysSocialWeb.UserAuth, :mount_current_scope}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    post = Posts.get_post!(id)
    comments = Posts.list_comments(post.id)

    liked =
      case socket.assigns[:current_scope] do
        %{user: user} -> Posts.liked_by?(post.id, user.id)
        _ -> false
      end

    socket =
      socket
      |> assign(:page_title, "Post")
      |> assign(:post, post)
      |> assign(:photo_index, 0)
      |> assign(:liked, liked)
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
end
