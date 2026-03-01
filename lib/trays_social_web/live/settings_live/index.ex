defmodule TraysSocialWeb.SettingsLive.Index do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.User
  alias TraysSocial.Uploads.{Photo, ImageProcessor}

  on_mount {TraysSocialWeb.UserAuth, :require_authenticated_user}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    changeset = Accounts.change_user_profile(user)
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)

    socket =
      socket
      |> assign(:page_title, "Settings")
      |> assign(:current_tab, :settings)
      |> assign(:user, user)
      |> assign(:changeset, changeset)
      |> assign(:email_changeset, email_changeset)
      |> assign(:password_changeset, password_changeset)
      |> assign(:email_form_error, nil)
      |> assign(:password_form_error, nil)
      |> allow_upload(:profile_photo,
        accept: ~w(.jpg .jpeg .png .heic),
        max_entries: 1,
        max_file_size: Photo.max_file_size()
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user_profile(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :profile_photo, ref)}
  end

  @impl true
  def handle_event("save_profile", %{"user" => user_params}, socket) do
    case upload_profile_photo(socket) do
      {:ok, photo_url} ->
        user_params =
          if photo_url,
            do: Map.put(user_params, "profile_photo_url", photo_url),
            else: user_params

        case Accounts.update_user_profile(socket.assigns.user, user_params) do
          {:ok, user} ->
            {:noreply,
             socket
             |> assign(:user, user)
             |> put_flash(:info, "Profile updated successfully")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, changeset: changeset)}
        end

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Photo upload failed. Please try again.")}
    end
  end

  @impl true
  def handle_event("change_email", %{"user" => %{"current_password" => current_password, "email" => email}}, socket) do
    user = socket.assigns.user

    if User.valid_password?(user, current_password) do
      email_changeset =
        user
        |> Accounts.change_user_email(%{"email" => email})
        |> Map.put(:action, :validate)

      if email_changeset.valid? do
        user_with_new_email = Ecto.Changeset.apply_changes(email_changeset)

        Accounts.deliver_user_update_email_instructions(
          user_with_new_email,
          user.email,
          fn token -> url(~p"/users/settings/confirm-email/#{token}") end
        )

        {:noreply,
         socket
         |> assign(:email_form_error, nil)
         |> assign(:email_changeset, Accounts.change_user_email(user))
         |> put_flash(:info, "A link to confirm your email change has been sent to #{email}.")}
      else
        {:noreply,
         socket
         |> assign(:email_form_error, nil)
         |> assign(:email_changeset, email_changeset)}
      end
    else
      {:noreply, assign(socket, :email_form_error, "Current password is incorrect.")}
    end
  end

  @impl true
  def handle_event("change_password", %{"user" => user_params}, socket) do
    user = socket.assigns.user
    current_password = Map.get(user_params, "current_password", "")

    if User.valid_password?(user, current_password) do
      case Accounts.update_user_password(user, user_params) do
        {:ok, _user} ->
          {:noreply,
           socket
           |> assign(:password_form_error, nil)
           |> put_flash(:info, "Password updated successfully. Please log in again.")
           |> push_navigate(to: ~p"/users/log-in")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply,
           socket
           |> assign(:password_form_error, nil)
           |> assign(:password_changeset, changeset)}
      end
    else
      {:noreply, assign(socket, :password_form_error, "Current password is incorrect.")}
    end
  end

  @impl true
  def handle_event("delete_account", _params, socket) do
    user = socket.assigns.user

    case Accounts.delete_account(user) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account deleted successfully")
         |> push_navigate(to: ~p"/")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete account")}
    end
  end

  defp upload_profile_photo(socket) do
    case socket.assigns.uploads.profile_photo.entries do
      [] ->
        {:ok, nil}

      _ ->
        urls =
          consume_uploaded_entries(socket, :profile_photo, fn %{path: path}, entry ->
            upload = %Plug.Upload{
              path: path,
              filename: entry.client_name,
              content_type: entry.client_type
            }

            case Photo.store(upload) do
              {:ok, url} -> {:ok, ImageProcessor.thumb_url(url)}
              {:error, reason} -> {:postpone, reason}
            end
          end)

        case urls do
          [url | _] -> {:ok, url}
          [] -> {:error, :upload_failed}
        end
    end
  end

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(:too_many_files), do: "Too many files selected"
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"
end
