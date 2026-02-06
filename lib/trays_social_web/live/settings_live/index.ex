defmodule TraysSocialWeb.SettingsLive.Index do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Accounts

  on_mount {TraysSocialWeb.UserAuth, :require_authenticated_user}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    changeset = Accounts.change_user_profile(user)

    socket =
      socket
      |> assign(:page_title, "Settings")
      |> assign(:user, user)
      |> assign(:changeset, changeset)

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
  def handle_event("save_profile", %{"user" => user_params}, socket) do
    case Accounts.update_user_profile(socket.assigns.user, user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:user, user)
         |> put_flash(:info, "Profile updated successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
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
end
