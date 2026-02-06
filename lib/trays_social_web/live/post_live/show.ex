defmodule TraysSocialWeb.PostLive.Show do
  use TraysSocialWeb, :live_view

  alias TraysSocial.Posts

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    post = Posts.get_post!(id)

    socket =
      socket
      |> assign(:page_title, "Post")
      |> assign(:post, post)

    {:ok, socket}
  end
end
