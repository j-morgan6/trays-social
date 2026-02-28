defmodule TraysSocialWeb.PostLive.New do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Posts
  alias TraysSocial.Posts.Post
  alias TraysSocial.Uploads.Photo

  on_mount {TraysSocialWeb.UserAuth, :require_authenticated_user}

  @impl true
  def mount(_params, _session, socket) do
    changeset = Posts.change_post(%Post{})

    socket =
      socket
      |> assign(:page_title, "Create Post")
      |> assign(:changeset, changeset)
      |> assign(:ingredient_rows, [0])
      |> assign(:next_ingredient_id, 1)
      |> assign(:step_rows, [0])
      |> assign(:next_step_id, 1)
      |> assign(:tool_rows, [])
      |> assign(:next_tool_id, 0)
      |> allow_upload(:photos,
        accept: ~w(.jpg .jpeg .png .heic),
        max_entries: 5,
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
  def handle_event("add-ingredient", _, socket) do
    id = socket.assigns.next_ingredient_id

    socket =
      socket
      |> update(:ingredient_rows, &(&1 ++ [id]))
      |> assign(:next_ingredient_id, id + 1)

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove-ingredient", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    socket = update(socket, :ingredient_rows, &Enum.reject(&1, fn row_id -> row_id == id end))
    {:noreply, socket}
  end

  @impl true
  def handle_event("add-step", _, socket) do
    id = socket.assigns.next_step_id

    socket =
      socket
      |> update(:step_rows, &(&1 ++ [id]))
      |> assign(:next_step_id, id + 1)

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove-step", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    socket = update(socket, :step_rows, &Enum.reject(&1, fn row_id -> row_id == id end))
    {:noreply, socket}
  end

  @impl true
  def handle_event("add-tool", _, socket) do
    id = socket.assigns.next_tool_id

    socket =
      socket
      |> update(:tool_rows, &(&1 ++ [id]))
      |> assign(:next_tool_id, id + 1)

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove-tool", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    socket = update(socket, :tool_rows, &Enum.reject(&1, fn row_id -> row_id == id end))
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photos, ref)}
  end

  @impl true
  def handle_event("save", %{"post" => post_params}, socket) do
    case socket.assigns.uploads.photos.entries do
      [] ->
        changeset =
          %Post{}
          |> Posts.change_post(post_params)
          |> Map.put(:action, :validate)

        {:noreply,
         socket
         |> put_flash(:error, "Please upload at least one photo")
         |> assign(:changeset, changeset)}

      _ ->
        upload_and_create(socket, post_params)
    end
  end

  defp upload_and_create(socket, post_params) do
    uploaded_urls =
      consume_uploaded_entries(socket, :photos, fn %{path: path}, entry ->
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

    case uploaded_urls do
      [first_url | _] ->
        post_photos =
          uploaded_urls
          |> Enum.with_index()
          |> Enum.map(fn {url, idx} -> %{"url" => url, "position" => idx} end)

        post_params =
          post_params
          |> Map.put("photo_url", first_url)
          |> Map.put("post_photos", post_photos)
          |> parse_tags()

        create_post(socket, post_params)

      [] ->
        {:noreply, put_flash(socket, :error, "Photo upload failed. Please try again.")}
    end
  end

  defp parse_tags(post_params) do
    tags_input = post_params["tags_input"] || ""

    tags =
      tags_input
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&%{"tag" => &1})

    Map.put(post_params, "post_tags", tags)
  end

  defp create_post(socket, post_params) do
    post_params = Map.put(post_params, "user_id", socket.assigns.current_scope.user.id)

    case Posts.create_post(post_params) do
      {:ok, post} ->
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
  defp error_to_string(:too_many_files), do: "Too many files selected"
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"
end
