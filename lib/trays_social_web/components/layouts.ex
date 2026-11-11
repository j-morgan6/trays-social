defmodule TraysSocialWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use TraysSocialWeb, :html

  alias TraysSocial.Features

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders a constrained content column for pages that want a centered, narrow
  layout (e.g. Settings, forms). The site-wide header, flash, and mobile nav
  are rendered by `root.html.heex` — this component is a thin wrapper that
  only sets the inner column width.

  ## Examples

      <Layouts.app>
        <h1>Content</h1>
      </Layouts.app>

  """
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl space-y-4 px-4 sm:px-6 lg:px-8">
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Site header and nav (W240, redesign canvas "Floating pills")
  # ---------------------------------------------------------------------------

  @doc """
  Which nav the root layout shows: `:recipe` (Home / My Tray / Search) for
  signed-in users when recipe-first is on, `:classic` (Feed / Find) for
  guests or with the flag off, and `:gated` for a signed-in user who has not
  confirmed their email (W203: no app nav, only Log out).
  """
  def nav_mode(nil), do: :classic
  def nav_mode(%{user: %{confirmed_at: nil}}), do: :gated
  def nav_mode(_scope), do: if(Features.recipe_first?(), do: :recipe, else: :classic)

  @doc """
  The Trays lockup: the handles mark (38px), a 9px gap, and "Trays" in
  Nunito 900 at 24px. The light mark is swapped for the on-dark mark by
  theme in app.css (`.logo-on-light` / `.logo-on-dark`).
  """
  attr :class, :any, default: nil

  def logo_lockup(assigns) do
    ~H"""
    <.link
      href={~p"/"}
      aria-label="Trays home"
      class={["inline-flex min-h-11 items-center gap-[9px] text-wordmark", @class]}
    >
      <img
        src={~p"/images/logo.svg"}
        alt=""
        width="38"
        height="30"
        class="logo-on-light w-[38px] h-auto"
      />
      <img
        src={~p"/images/logo-on-dark.svg"}
        alt=""
        width="38"
        height="30"
        class="logo-on-dark w-[38px] h-auto"
      />
      <span class="font-display text-2xl font-black leading-none tracking-[-0.5px]">Trays</span>
    </.link>
    """
  end

  @doc """
  The sticky site header: lockup, the pill tabs, and the actions (amber
  Create, bell with an amber unread dot, avatar menu). In the recipe nav the
  tabs drop to a second row below md, as the canvas draws the phone header.
  """
  attr :nav_mode, :atom, required: true, values: [:recipe, :classic, :gated]
  attr :current_scope, :any, default: nil
  attr :current_tab, :atom, default: nil
  attr :unread_notifications, :integer, default: 0

  def site_header(assigns) do
    assigns =
      assign(
        assigns,
        :tabs,
        nav_tabs(assigns.nav_mode, assigns.current_scope, assigns.current_tab)
      )

    ~H"""
    <header class="sticky top-0 z-50 border-b border-hairline-strong bg-pill backdrop-blur-[20px]">
      <div class="mx-auto flex min-h-16 max-w-7xl items-center justify-between gap-3 px-3.5 md:h-[72px] md:px-8">
        <div class="flex flex-1 items-center">
          <.logo_lockup />
        </div>
        <.nav_pill :if={@tabs != []} tabs={@tabs} placement={:desktop} />
        <div class="flex flex-1 items-center justify-end gap-1 sm:gap-2.5">
          <.link
            :if={@nav_mode == :classic}
            href={~p"/explore"}
            class="hidden lg:inline-flex items-center gap-2 h-10 w-64 xl:w-80 px-3.5 rounded-full bg-base-100 ring-1 ring-inset ring-border text-muted text-[13px] hover:text-base-content transition-colors"
          >
            <.icon name="hero-magnifying-glass" class="size-4" />
            <span>Search recipes, cooks, ingredients…</span>
          </.link>
          <.header_actions
            nav_mode={@nav_mode}
            current_scope={@current_scope}
            unread_notifications={@unread_notifications}
          />
        </div>
      </div>
      <div :if={@nav_mode == :recipe} class="px-3.5 pb-2.5 md:hidden">
        <.nav_pill tabs={@tabs} placement={:mobile} />
      </div>
    </header>
    """
  end

  defp nav_tabs(:recipe, _scope, tab) do
    [
      %{label: "Home", path: ~p"/home", active: tab in [:feed, :home]},
      %{label: "My Tray", path: ~p"/my-tray", active: tab == :my_tray},
      %{label: "Search", path: ~p"/search", active: tab == :explore}
    ]
  end

  defp nav_tabs(:classic, scope, tab) do
    tabs = [
      %{label: "Feed", path: ~p"/feed", active: tab in [:feed, :home]},
      %{label: "Find", path: ~p"/explore", active: tab == :explore}
    ]

    if scope,
      do: tabs ++ [%{label: "My Tray", path: ~p"/my-tray", active: tab == :my_tray}],
      else: tabs
  end

  defp nav_tabs(:gated, _scope, _tab), do: []

  attr :tabs, :list, required: true
  attr :placement, :atom, required: true, values: [:desktop, :mobile]

  defp nav_pill(%{placement: :desktop} = assigns) do
    ~H"""
    <nav
      aria-label="Main"
      class="hidden md:flex items-center gap-0.5 rounded-full bg-pill p-1 shadow-pill backdrop-blur-[20px]"
    >
      <.link
        :for={tab <- @tabs}
        href={tab.path}
        aria-current={tab.active && "page"}
        class={[
          "inline-flex min-h-[38px] items-center rounded-full px-[15px] text-sm font-semibold transition-colors",
          tab_state(tab.active)
        ]}
      >
        {tab.label}
      </.link>
    </nav>
    """
  end

  defp nav_pill(%{placement: :mobile} = assigns) do
    ~H"""
    <nav
      aria-label="Main"
      class="flex items-center gap-0.5 rounded-full bg-pill p-1 shadow-pill backdrop-blur-[20px]"
    >
      <.link
        :for={tab <- @tabs}
        navigate={tab.path}
        aria-current={tab.active && "page"}
        class={[
          "inline-flex min-h-[38px] flex-1 items-center justify-center rounded-full px-[15px] text-sm font-semibold transition-colors",
          tab_state(tab.active)
        ]}
      >
        <span>{tab.label}</span>
      </.link>
    </nav>
    """
  end

  defp tab_state(true), do: "bg-primary text-primary-content"
  defp tab_state(false), do: "text-muted hover:text-base-content"

  attr :nav_mode, :atom, required: true
  attr :current_scope, :any, default: nil
  attr :unread_notifications, :integer, default: 0

  defp header_actions(%{nav_mode: :gated} = assigns) do
    ~H"""
    <.link
      href={~p"/users/log-out"}
      method="delete"
      class="inline-flex min-h-11 items-center rounded-full px-4 text-sm font-semibold hover:bg-base-300/60"
    >
      Log out
    </.link>
    """
  end

  defp header_actions(%{current_scope: nil} = assigns) do
    ~H"""
    <.link
      href={~p"/users/log-in"}
      class="inline-flex min-h-11 items-center rounded-full px-4 text-sm font-semibold hover:bg-base-300/60"
    >
      Log in
    </.link>
    <.link
      href={~p"/users/register"}
      class="inline-flex min-h-11 items-center rounded-full bg-primary px-4 text-sm font-semibold text-primary-content hover:bg-primary-light"
    >
      Sign up
    </.link>
    """
  end

  defp header_actions(assigns) do
    ~H"""
    <%!-- Amber Create: amber is the "make something" colour. --%>
    <.link
      href={~p"/posts/new"}
      aria-label="New recipe"
      class="inline-flex size-11 items-center justify-center gap-2 rounded-full bg-accent text-[15px] font-semibold text-accent-content hover:brightness-95 sm:size-auto sm:min-h-11 sm:pl-2.5 sm:pr-[18px]"
    >
      <.icon name="hero-plus" class="size-5" />
      <span class="hidden sm:inline">New recipe</span>
    </.link>
    <.link
      navigate={~p"/notifications"}
      aria-label="Notifications"
      class="relative grid size-[46px] place-items-center rounded-full hover:bg-base-300/60"
    >
      <.icon name="hero-bell" class="size-5" />
      <span
        :if={@unread_notifications > 0}
        class="absolute right-[11px] top-[11px] size-[9px] rounded-full bg-accent ring-2 ring-base-100"
      >
      </span>
    </.link>
    <div class="dropdown dropdown-end">
      <div tabindex="0" role="button" aria-label="Account menu" class="cursor-pointer">
        <.user_avatar
          username={@current_scope.user.username}
          photo_url={@current_scope.user.profile_photo_url}
          size="md"
        />
      </div>
      <ul
        tabindex="0"
        class="menu menu-sm dropdown-content mt-3 z-[1] p-2 shadow-lg bg-base-100 rounded-box w-52 border border-hairline-strong"
      >
        <li class="menu-title">
          <span class="text-base-content font-semibold">@{@current_scope.user.username}</span>
        </li>
        <li><.link href={~p"/@#{@current_scope.user.username}"}>Your Profile</.link></li>
        <li><.link href={~p"/users/settings"}>Settings</.link></li>
        <div class="divider my-0"></div>
        <li>
          <.link href={~p"/users/log-out"} method="delete" class="text-error">Log out</.link>
        </li>
      </ul>
    </div>
    """
  end

  @doc """
  Bottom tab bar for the classic nav below md (Feed / Profile / Post /
  Explore). The recipe nav has no bottom bar: its tabs sit in the header.
  """
  attr :current_scope, :any, default: nil
  attr :current_tab, :atom, default: nil

  def classic_tab_bar(assigns) do
    ~H"""
    <nav
      aria-label="Main"
      class="fixed inset-x-0 bottom-0 z-50 border-t border-hairline-strong bg-pill backdrop-blur-[20px] md:hidden"
    >
      <div class="flex h-16 items-center justify-around">
        <.bar_item
          navigate={~p"/feed"}
          icon="hero-home"
          label="Feed"
          active={@current_tab in [:feed, :home]}
        />
        <%= if @current_scope do %>
          <.bar_item
            navigate={~p"/@#{@current_scope.user.username}"}
            icon="hero-user"
            label="Profile"
            active={@current_tab == :profile}
          />
          <.bar_item
            navigate={~p"/posts/new"}
            icon="hero-plus-circle"
            icon_size="w-7 h-7"
            label="Post"
            active={@current_tab == :new_post}
          />
        <% else %>
          <.bar_item navigate={~p"/users/log-in"} icon="hero-user" label="Profile" active={false} />
          <.bar_item
            navigate={~p"/users/log-in"}
            icon="hero-plus-circle"
            icon_size="w-7 h-7"
            label="Post"
            active={false}
          />
        <% end %>
        <.bar_item
          navigate={~p"/explore"}
          icon="hero-magnifying-glass"
          label="Explore"
          active={@current_tab == :explore}
        />
      </div>
    </nav>
    """
  end

  attr :navigate, :string, required: true
  attr :icon, :string, required: true, doc: "a literal hero-* icon class"
  attr :icon_size, :string, default: "w-6 h-6"
  attr :label, :string, required: true
  attr :active, :boolean, required: true

  defp bar_item(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "flex flex-col items-center gap-0.5 px-4 py-2 text-xs font-medium transition-colors",
        if(@active, do: "text-primary-ink", else: "text-muted hover:text-base-content")
      ]}
    >
      <span class={[@icon, @icon_size]}></span>
      <span>{@label}</span>
    </.link>
    """
  end
end
