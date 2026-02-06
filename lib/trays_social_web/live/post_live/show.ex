defmodule TraysSocialWeb.PostLive.Show do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Posts

  on_mount {TraysSocialWeb.UserAuth, :mount_current_scope}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    post = Posts.get_post!(id)

    socket =
      socket
      |> assign(:page_title, "Post")
      |> assign(:post, post)

    {:ok, socket}
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
end
