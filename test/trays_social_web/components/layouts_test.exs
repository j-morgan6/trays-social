defmodule TraysSocialWeb.LayoutsTest do
  # W240: the redesigned site header (lockup, pill tabs, Create, bell, avatar).
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias TraysSocial.Accounts.Scope
  alias TraysSocial.Accounts.User
  alias TraysSocialWeb.Layouts

  defp scope(confirmed_at) do
    %Scope{user: %User{username: "ren", confirmed_at: confirmed_at}}
  end

  test "logo_lockup renders both marks, the wordmark and a home label" do
    assigns = %{}
    html = rendered_to_string(~H|<Layouts.logo_lockup />|)

    assert html =~ ~s(src="/images/logo.svg")
    assert html =~ ~s(src="/images/logo-on-dark.svg")
    assert html =~ "logo-on-light"
    assert html =~ "logo-on-dark"
    assert html =~ "font-black"
    assert html =~ ~s(aria-label="Trays home")
  end

  describe "site_header/1" do
    test "recipe nav shows the pill tabs, Create, the bell and its unread dot" do
      assigns = %{scope: scope(~U[2026-01-01 00:00:00Z])}

      html =
        rendered_to_string(~H"""
        <Layouts.site_header
          nav_mode={:recipe}
          current_scope={@scope}
          current_tab={:home}
          unread_notifications={2}
        />
        """)

      assert html =~ ~s(aria-label="Main")
      assert html =~ ~s(aria-current="page")
      assert html =~ "bg-primary text-primary-content"
      assert html =~ ~s(aria-label="Notifications")
      assert html =~ ~s(href="/notifications")
      assert html =~ "New recipe"
      assert html =~ ~s(href="/posts/new")
      assert html =~ "size-[9px] rounded-full bg-accent"
    end

    test "no unread notifications means no dot" do
      assigns = %{scope: scope(~U[2026-01-01 00:00:00Z])}

      html =
        rendered_to_string(~H"""
        <Layouts.site_header nav_mode={:recipe} current_scope={@scope} unread_notifications={0} />
        """)

      refute html =~ "size-[9px] rounded-full bg-accent"
    end

    test "gated nav shows only Log out" do
      assigns = %{scope: scope(nil)}

      html =
        rendered_to_string(~H"""
        <Layouts.site_header nav_mode={:gated} current_scope={@scope} />
        """)

      assert html =~ "Log out"
      refute html =~ ~s(aria-label="Main")
      refute html =~ "New recipe"
    end
  end

  describe "flash groups (D127)" do
    defp root_html(assigns) do
      assigns
      |> Map.merge(%{current_scope: nil, inner_content: "page"})
      |> Layouts.root()
      |> rendered_to_string()
    end

    test "controller pages still render the root flash group and keep :inline_flash" do
      flash = %{"info" => "Saved the thing", "error" => "Broke the thing"}

      html = root_html(%{flash: flash})
      assert html =~ ~s(id="flash-group")
      assert html =~ "Saved the thing"
      assert html =~ "Broke the thing"

      inline = root_html(%{flash: flash, inline_flash: true})
      assert inline =~ ~s(id="flash-group")
      refute inline =~ "Saved the thing"
      refute inline =~ "Broke the thing"
    end

    test "the root layout leaves the group to the live layout when it wraps a LiveView" do
      html = root_html(%{flash: %{"info" => "Hello"}, live_module: SomeLive})

      refute html =~ ~s(id="flash-group")
      refute html =~ "Hello"
    end

    test "live/1 renders the group and the content, dropping inline kinds" do
      flash = %{"info" => "Saved the thing", "error" => "Broke the thing"}

      html = rendered_to_string(Layouts.live(%{flash: flash, inner_content: "page"}))
      assert html =~ ~s(id="flash-group")
      assert html =~ "Saved the thing"
      assert html =~ "Broke the thing"
      assert html =~ "page"

      inline =
        rendered_to_string(
          Layouts.live(%{flash: flash, inline_flash: [:error], inner_content: "page"})
        )

      assert inline =~ "Saved the thing"
      refute inline =~ "Broke the thing"
    end
  end

  test "nav_mode/1 picks classic for guests and gated for unconfirmed users" do
    assert Layouts.nav_mode(nil) == :classic
    assert nil |> scope() |> Layouts.nav_mode() == :gated
  end
end
