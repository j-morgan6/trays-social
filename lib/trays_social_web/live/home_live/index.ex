defmodule TraysSocialWeb.HomeLive.Index do
  @moduledoc """
  The recipe-first Home page: welcome for new cooks, Jump back in, Tonight,
  Friends' trays, and a finite New from people you follow row.
  """
  use TraysSocialWeb, :live_view

  alias TraysSocial.Home
  alias TraysSocialWeb.HomeFormatting

  on_mount {TraysSocialWeb.UserAuth, :require_authenticated_user}
  on_mount {TraysSocialWeb.UserAuth, :require_confirmed_user}
  on_mount {TraysSocialWeb.NotificationsHook, :mount_notifications}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Home")
      |> assign(:current_tab, :home)

    if connected?(socket) do
      # Home.build/2 still picks Tonight by UTC "today". The browser's UTC
      # offset (W242) only drives the greeting kicker; without a valid offset
      # the kicker is left out rather than guessed.
      now = DateTime.utc_now()
      local_now = socket |> get_connect_params() |> tz_offset() |> HomeFormatting.local_now(now)

      {:ok,
       assign(socket,
         home: Home.build(socket.assigns.current_scope.user),
         loading: false,
         now: now,
         kicker: local_now && HomeFormatting.greeting_kicker(local_now)
       )}
    else
      {:ok, assign(socket, home: nil, loading: true, now: nil, kicker: nil)}
    end
  end

  defp tz_offset(%{"tz_offset" => offset}), do: offset
  defp tz_offset(_params), do: nil

  def post_title(post), do: TraysSocialWeb.ExploreLive.Index.post_title(post)

  def welcome?(home), do: home.jump_back_in == [] and home.friends_trays == []

  @doc "The New badge for a card on the new-from-follows row."
  def new_badge(post, now), do: if(HomeFormatting.new?(post.inserted_at, now), do: :new)
end
