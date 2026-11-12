defmodule TraysSocialWeb.MyTrayLive.Index do
  @moduledoc """
  My Tray — a cook's saved recipes. The header's "My Tray" nav item
  lives here. Backed by the existing bookmark store: each saved post
  becomes a tray entry.

  W246: with recipe_first on, a pill switch picks My recipes or Saved
  (`?list=saved`), each a uniform 4:3 grid. Collections and the planner
  stay off the web (spec D16: neither has a web route). With the flag off
  the page shows only the Saved grid, as before.
  """
  use TraysSocialWeb, :live_view

  alias TraysSocial.Posts
  alias TraysSocialWeb.HomeFormatting
  alias TraysSocialWeb.TrayFormatting

  on_mount {TraysSocialWeb.UserAuth, :require_authenticated_user}
  on_mount {TraysSocialWeb.UserAuth, :require_confirmed_user}
  on_mount {TraysSocialWeb.NotificationsHook, :mount_notifications}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    recipe_first = TraysSocial.Features.recipe_first?()

    if connected?(socket) do
      bookmarks = Posts.list_bookmarks(user.id, limit: 40)

      {:ok,
       socket
       |> assign_static(recipe_first)
       |> assign(:loading, false)
       |> assign(:bookmarks, bookmarks)
       |> assign(:saved_count, length(bookmarks))
       |> assign(:my_recipes, my_recipes(recipe_first, user))}
    else
      {:ok,
       socket
       |> assign_static(recipe_first)
       |> assign(:loading, true)
       |> assign(:bookmarks, [])
       |> assign(:saved_count, 0)
       |> assign(:my_recipes, [])}
    end
  end

  defp assign_static(socket, recipe_first) do
    socket
    |> assign(:page_title, "My Tray")
    |> assign(:current_tab, :my_tray)
    |> assign(:recipe_first, recipe_first)
    |> assign(:now, DateTime.utc_now())
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, :list, list_param(params["list"]))}
  end

  # Only "saved" picks the Saved list; anything else is My recipes.
  defp list_param("saved"), do: :saved
  defp list_param(_value), do: :recipes

  # The switch's two pills. Counts stay hidden until the lists load, and
  # come from the loaded lists (each capped at 40), like iOS.
  defp list_options(assigns) do
    loaded = !assigns.loading

    [
      %{
        label: "My recipes",
        count: if(loaded, do: length(assigns.my_recipes)),
        patch: ~p"/my-tray",
        selected: assigns.list == :recipes
      },
      %{
        label: "Saved",
        count: if(loaded, do: assigns.saved_count),
        patch: ~p"/my-tray?list=saved",
        selected: assigns.list == :saved
      }
    ]
  end

  defp subtitle(%{loading: true}), do: nil

  defp subtitle(%{recipe_first: true} = assigns),
    do: assigns.my_recipes |> length() |> TrayFormatting.header_subtitle(assigns.saved_count)

  defp subtitle(%{saved_count: 0}), do: nil
  defp subtitle(%{saved_count: count}), do: "#{count} saved"

  # Recipe-first labels legacy photo posts among the saves; classic shows
  # every save as a recipe card, as before.
  defp photo_post?(post, recipe_first), do: recipe_first and post.type != "recipe"

  defp card_title(post, true), do: post.caption || ""
  defp card_title(post, false), do: TrayFormatting.post_title(post)

  # Recipe-first: the signed-in cook's own recipes, listed above Saved.
  # Legacy photo posts are left out; they stay reachable from the profile.
  defp my_recipes(true, user), do: Posts.list_posts_by_user(user.id, limit: 40, filter: "recipes")
  defp my_recipes(_recipe_first, _user), do: []
end
