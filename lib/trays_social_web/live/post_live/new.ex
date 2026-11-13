defmodule TraysSocialWeb.PostLive.New do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Posts
  alias TraysSocial.Posts.Post
  alias TraysSocial.Uploads.Photo

  on_mount {TraysSocialWeb.UserAuth, :require_authenticated_user}
  on_mount {TraysSocialWeb.UserAuth, :require_confirmed_user}
  on_mount {TraysSocialWeb.NotificationsHook, :mount_notifications}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Create Post")
      |> assign(:current_tab, :new_post)
      |> assign(:post_type, nil)
      |> assign(:recipe_first, TraysSocial.Features.recipe_first?())
      # D127: save errors show in the editor's inline note, so the live
      # layout's toast group skips the error kind and nothing shows twice.
      |> assign(:inline_flash, [:error])

    # Recipe-first: skip the type picker and open straight on the recipe
    # form. The picker code stays for flag-off.
    socket = if socket.assigns.recipe_first, do: init_form(socket, "recipe"), else: socket

    {:ok, socket}
  end

  defp init_form(socket, type) do
    changeset = Posts.change_post(%Post{}, %{type: type})

    socket
    |> assign(:post_type, type)
    |> assign(:changeset, changeset)
    |> assign(:form_params, %{})
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
  end

  @impl true
  def handle_event("select-type", %{"type" => type}, socket) when type in ~w(recipe post) do
    # Recipe-first: the form was opened as a recipe in mount and no picker
    # is rendered, so any select-type is stale or crafted. Ignoring it also
    # avoids re-running allow_upload over active upload entries.
    if socket.assigns.recipe_first do
      {:noreply, socket}
    else
      {:noreply, init_form(socket, type)}
    end
  end

  @impl true
  def handle_event("back-to-picker", _, %{assigns: %{recipe_first: true}} = socket) do
    {:noreply, socket}
  end

  def handle_event("back-to-picker", _, socket) do
    socket =
      socket
      |> assign(:post_type, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    post_params = Map.put(post_params, "type", socket.assigns.post_type)

    changeset =
      %Post{}
      |> Posts.change_post(post_params)
      |> Map.put(:action, :validate)

    # W250: a save error from the flash is shown inline in the editor
    # (the toast group skips it via :inline_flash, D127). Any edit,
    # including attaching a photo, clears it so a stale message does not
    # stay after the user acted on it.
    {:noreply,
     socket
     |> clear_flash(:error)
     |> assign(:changeset, changeset)
     |> assign(:form_params, post_params)}
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
    post_params = Map.put(post_params, "type", socket.assigns.post_type)

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
    require Logger

    entries = socket.assigns.uploads.photos.entries
    Logger.warning("upload_and_create: #{length(entries)} entries")

    for entry <- entries do
      Logger.warning(
        "  entry: #{entry.client_name}, done?=#{entry.done?}, progress=#{entry.progress}"
      )
    end

    uploaded_urls = consume_photo_uploads(socket)
    Logger.warning("uploaded_urls: #{inspect(uploaded_urls)}")

    case uploaded_urls do
      [first_url | _] ->
        post_params = build_post_params_with_photos(post_params, first_url, uploaded_urls)
        create_post(socket, post_params)

      [] ->
        {:noreply, put_flash(socket, :error, "Photo upload failed. Please try again.")}
    end
  end

  defp consume_photo_uploads(socket) do
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
  end

  defp build_post_params_with_photos(post_params, first_url, uploaded_urls) do
    post_photos =
      uploaded_urls
      |> Enum.with_index()
      |> Enum.map(fn {url, idx} -> %{"url" => url, "position" => idx} end)

    post_params
    |> Map.put("photo_url", first_url)
    |> Map.put("post_photos", post_photos)
    |> parse_tags()
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
    require Logger

    user_id = socket.assigns.current_scope.user.id

    # D44: user_id passed positionally; never via attrs (would be dropped
    # anyway since Post.changeset doesn't cast it, but be explicit).
    post_params =
      post_params
      |> Map.drop(["user_id"])
      |> Map.put("type", socket.assigns.post_type)

    Logger.warning("create_post params: #{inspect(Map.keys(post_params))}")

    case Posts.create_post(user_id, post_params) do
      {:ok, post} ->
        Logger.warning("Post created successfully, id=#{post.id}")

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
        Logger.warning("Post creation failed: #{inspect(changeset.errors)}")
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(:too_many_files), do: "Too many files selected"
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"

  defp field_value(form_params, section, row_id, field) do
    get_in(form_params, [section, to_string(row_id), field]) || ""
  end

  # ---------------------------------------------------------------------------
  # Editor view helpers (W250). Presentation only: they read the form params
  # and upload entries the events above already keep, and change no event,
  # param or validation.
  # ---------------------------------------------------------------------------

  # Errors for a field once the user has touched it, as the core <.input>
  # shows them. The editor renders them as amber notes, never red (canvas).
  defp field_errors(%Phoenix.HTML.FormField{} = field) do
    if Phoenix.Component.used_input?(field),
      do: Enum.map(field.errors, &TraysSocialWeb.CoreComponents.translate_error/1),
      else: []
  end

  # The preview card's title: the caption's first line or sentence, by the
  # rule the recipe page uses (D126). Empty when there is none, so the
  # preview shows its placeholder.
  defp preview_title(caption) when is_binary(caption),
    do: TraysSocialWeb.TrayFormatting.caption_title(caption, "")

  defp preview_title(_caption), do: ""

  defp preview_time(value) do
    case positive_integer(value) do
      nil -> nil
      minutes -> "#{minutes} min"
    end
  end

  # What the aside's checklist shows for a recipe: the things a post needs,
  # read from the params the validate event stores. Done means filled in,
  # not valid; the changeset still decides on save.
  defp editor_checklist(form_params, photo_entries) do
    [
      {"A photo", photo_entries != []},
      {"A name (recommended)", present?(form_params["caption"])},
      {"Total time", positive_integer(form_params["cooking_time_minutes"]) != nil},
      {"At least one ingredient", any_row_filled?(form_params, "ingredients", "name")},
      {"At least one step", any_row_filled?(form_params, "cooking_steps", "description")}
    ]
  end

  defp any_row_filled?(form_params, section, field) do
    case form_params[section] do
      rows when is_map(rows) -> rows |> Map.values() |> Enum.any?(&present?(&1[field]))
      _ -> false
    end
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false

  defp positive_integer(value) when is_integer(value) and value > 0, do: value

  defp positive_integer(value) when is_binary(value) do
    case value |> String.trim() |> Integer.parse() do
      {n, ""} when n > 0 -> n
      _ -> nil
    end
  end

  defp positive_integer(_value), do: nil

  # ---------------------------------------------------------------------------
  # Editor building blocks (W250), from the canvas Create artboard.
  # ---------------------------------------------------------------------------

  attr :id, :string, required: true
  attr :title, :string, default: nil
  attr :aside, :string, default: nil, doc: "muted note beside the title"
  attr :class, :any, default: nil
  slot :inner_block, required: true

  defp editor_card(assigns) do
    ~H"""
    <section
      id={@id}
      aria-label={@title}
      class={["min-w-0 rounded-[22px] bg-base-100 p-4 shadow-card md:p-[22px]", @class]}
    >
      <div :if={@title} class="mb-3 flex items-baseline justify-between gap-2.5">
        <h2 class="font-display text-lg font-extrabold">{@title}</h2>
        <span :if={@aside} class="text-[13px] text-muted">{@aside}</span>
      </div>
      {render_slot(@inner_block)}
    </section>
    """
  end

  attr :id, :string, default: nil
  attr :messages, :list, required: true

  defp field_note(assigns) do
    ~H"""
    <div :if={@messages != []} id={@id} data-role="field-note" class="mt-2.5 flex flex-col gap-1.5">
      <p
        :for={msg <- @messages}
        class="flex items-center gap-2 rounded-xl bg-accent/25 px-3 py-2 text-[13.5px] text-base-content"
      >
        <.icon name="hero-exclamation-circle" class="size-4 shrink-0" />
        <span class="min-w-0 break-words">{msg}</span>
      </p>
    </div>
    """
  end

  attr :rest, :global, include: ~w(phx-click)
  slot :inner_block, required: true

  defp add_row_button(assigns) do
    ~H"""
    <button
      type="button"
      class="inline-flex min-h-11 items-center gap-2 rounded-full bg-mint-tint pl-3 pr-4 text-[15px] font-semibold text-primary-ink transition hover:brightness-95 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
      {@rest}
    >
      <.icon name="hero-plus" class="size-4" />
      {render_slot(@inner_block)}
    </button>
    """
  end
end
