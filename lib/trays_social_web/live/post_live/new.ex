defmodule TraysSocialWeb.PostLive.New do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Posts
  alias TraysSocial.Posts.Post
  alias TraysSocial.Uploads.Photo

  @impl true
  def mount(_params, _session, socket) do
    changeset = Posts.change_post(%Post{})

    socket =
      socket
      |> assign(:page_title, "Create Post")
      |> assign(:changeset, changeset)
      |> assign(:uploaded_photo_url, nil)
      |> allow_upload(:photo,
        accept: ~w(.jpg .jpeg .png .heic),
        max_entries: 1,
        max_file_size: Photo.max_file_size()
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    changeset =
      %Post{}
      |> Posts.change_post(post_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event("save", %{"post" => post_params}, socket) do
    # Upload photo first
    case upload_photo(socket) do
      {:ok, photo_url} ->
        post_params = Map.put(post_params, "photo_url", photo_url)
        create_post(socket, post_params)

      {:error, :no_file} ->
        {:noreply,
         socket
         |> put_flash(:error, "Please upload a photo")
         |> assign(:changeset, Posts.change_post(%Post{}, post_params))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to upload photo: #{inspect(reason)}")
         |> assign(:changeset, Posts.change_post(%Post{}, post_params))}
    end
  end

  defp upload_photo(socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :photo, fn %{path: path}, entry ->
        # Create a Plug.Upload struct for Photo.store/1
        upload = %Plug.Upload{
          path: path,
          filename: entry.client_name,
          content_type: entry.client_type
        }

        case Photo.store(upload) do
          {:ok, url} -> {:ok, url}
          {:error, reason} -> {:postpone, reason}
        end
      end)

    case uploaded_files do
      [url | _] -> {:ok, url}
      [] -> {:error, :no_file}
    end
  end

  defp create_post(socket, post_params) do
    # Add current user ID
    post_params = Map.put(post_params, "user_id", socket.assigns.current_user.id)

    case Posts.create_post(post_params) do
      {:ok, post} ->
        # Broadcast new post to feed
        Phoenix.PubSub.broadcast(
          TraysSocial.PubSub,
          "posts:new",
          {:new_post, post}
        )

        {:noreply,
         socket
         |> put_flash(:info, "Post created successfully!")
         |> push_navigate(to: ~p"/posts/#{post.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"
end
