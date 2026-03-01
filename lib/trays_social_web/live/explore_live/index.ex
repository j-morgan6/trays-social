defmodule TraysSocialWeb.ExploreLive.Index do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Posts

  on_mount {TraysSocialWeb.UserAuth, :mount_current_scope}
  on_mount {TraysSocialWeb.NotificationsHook, :mount_notifications}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      trending = Posts.list_trending_posts(10)
      recent = Posts.list_recent_posts(10)
      tags = Posts.list_top_tags(6)
      tag_sections = Posts.list_posts_by_tags(tags, 8)

      {:ok,
       socket
       |> assign(:page_title, "Explore")
       |> assign(:current_tab, :explore)
       |> assign(:loading, false)
       |> assign(:trending, trending)
       |> assign(:recent, recent)
       |> assign(:tag_sections, tag_sections)}
    else
      {:ok,
       socket
       |> assign(:page_title, "Explore")
       |> assign(:current_tab, :explore)
       |> assign(:loading, true)
       |> assign(:trending, [])
       |> assign(:recent, [])
       |> assign(:tag_sections, [])}
    end
  end
end
