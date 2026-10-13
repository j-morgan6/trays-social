defmodule TraysSocialWeb.RequireConfirmedTest do
  @moduledoc """
  W203: every logged-in web page is gated on a confirmed email. An
  unconfirmed user is sent to /users/confirm-required, which offers only
  resend, change email (settings) and log out.
  """
  use TraysSocialWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import TraysSocial.AccountsFixtures
  import TraysSocial.PostsFixtures

  alias TraysSocial.Accounts

  @confirm_page "/users/confirm-required"

  # Every logged-in route outside the escape hatches (settings and the
  # confirm page). Kept explicit so a reader sees what is gated; the
  # router-driven test below catches a LiveView added without the hook.
  defp gated_paths(username) do
    [
      ~p"/home",
      ~p"/feed",
      ~p"/explore",
      ~p"/search",
      ~p"/@#{username}",
      ~p"/@#{username}/followers",
      ~p"/@#{username}/following",
      ~p"/welcome",
      ~p"/posts/new",
      ~p"/my-tray",
      ~p"/notifications"
    ]
  end

  describe "confirmed users" do
    test "confirmed user reaches /home normally", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      assert {:ok, _lv, _html} = live(conn, ~p"/home")
    end

    test "the confirm page sends a confirmed user to their signed-in home", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture()) |> get(@confirm_page)

      assert redirected_to(conn) == TraysSocialWeb.UserAuth.signed_in_path(conn)
    end
  end

  describe "unconfirmed users" do
    setup %{conn: conn} do
      user = unconfirmed_user_fixture()
      %{user: user, conn: log_in_user(conn, user)}
    end

    test "unconfirmed user is redirected from /home to the confirm page", %{
      conn: conn,
      user: user
    } do
      assert {:error, {:redirect, %{to: @confirm_page}}} = live(conn, ~p"/home")

      for path <- gated_paths(user.username) do
        assert redirected_to(get(conn, path)) == @confirm_page,
               "expected #{path} to redirect an unconfirmed user to #{@confirm_page}"
      end
    end

    test "unconfirmed user can still reach settings, resend and log out", %{
      conn: conn,
      user: user
    } do
      # The confirm page renders (no redirect loop) and offers only the
      # ways out; the old banner and the app nav are gone.
      html = conn |> get(@confirm_page) |> html_response(200)
      doc = LazyHTML.from_document(html)

      assert html =~ "Verify your email"
      assert html =~ user.email
      assert has?(doc, ~s|form#resend-confirmation-form[action="/users/confirmation/resend"]|)
      assert has?(doc, ~s|a#confirm-required-change-email[href="/users/settings"]|)

      assert has?(
               doc,
               ~s|a#confirm-required-log-out[href="/users/log-out"][data-method="delete"]|
             )

      refute html =~ "Please confirm your email address to post"
      refute has?(doc, ~s|a[href="/my-tray"]|)
      refute has?(doc, ~s|a[href="/posts/new"]|)

      assert {:ok, _lv, _html} = live(conn, ~p"/users/settings")

      resend = post(conn, ~p"/users/confirmation/resend")
      assert redirected_to(resend) == @confirm_page

      log_out = delete(conn, ~p"/users/log-out")
      assert redirected_to(log_out) == ~p"/"
    end

    test "the emailed confirmation link is not gated and lifts the gate", %{
      conn: conn,
      user: user
    } do
      token =
        extract_user_token(fn url_fun ->
          Accounts.deliver_user_confirmation_instructions(user, url_fun)
        end)

      confirmed = get(conn, ~p"/users/confirm/#{token}")
      assert redirected_to(confirmed) == ~p"/"
      assert Phoenix.Flash.get(confirmed.assigns.flash, :info) == "Email confirmed successfully."

      # Same session, as if the user confirmed in another tab and reloaded.
      assert {:ok, _lv, _html} = live(conn, ~p"/home")
    end

    test "following a change-email link confirms the user", %{conn: conn, user: user} do
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      assert redirected_to(get(conn, ~p"/users/settings/confirm-email/#{token}")) ==
               ~p"/users/settings"

      assert {:ok, _lv, _html} = live(conn, ~p"/home")
    end

    test "a public recipe page redirects an unconfirmed user to the confirm page", %{
      conn: conn
    } do
      post = post_fixture(%{user_id: user_fixture().id})

      assert {:error, {:redirect, %{to: @confirm_page}}} = live(conn, ~p"/posts/#{post.id}")
    end
  end

  describe "logged-out visitors" do
    test "logged-out visitors still see public recipe pages", %{conn: conn} do
      post = post_fixture(%{user_id: user_fixture().id})

      assert {:ok, _lv, _html} = live(conn, ~p"/posts/#{post.id}")
    end

    test "the confirm page requires a login", %{conn: conn} do
      assert redirected_to(get(conn, @confirm_page)) == ~p"/users/log-in"
    end
  end

  describe "on_mount coverage" do
    # Live navigation between LiveViews never re-runs router plugs, so the
    # plug alone is not enough: each logged-in LiveView must carry the
    # on_mount gate itself. live_isolated/3 skips the router entirely, so a
    # redirect here can only come from the module's own on_mount.
    test "every logged-in LiveView gates unconfirmed users via on_mount", %{conn: conn} do
      session = %{
        "user_token" => Accounts.generate_user_session_token(unconfirmed_user_fixture())
      }

      escape_hatches = [TraysSocialWeb.SettingsLive.Index]

      modules =
        TraysSocialWeb.Router
        |> Phoenix.Router.routes()
        |> Enum.filter(&Map.has_key?(&1.metadata, :phoenix_live_view))
        |> Enum.reject(&String.starts_with?(&1.path, ["/admin", "/dev"]))
        |> Enum.map(&elem(&1.metadata.phoenix_live_view, 0))
        |> Enum.uniq()
        |> Kernel.--(escape_hatches)

      assert TraysSocialWeb.HomeLive.Index in modules
      assert TraysSocialWeb.PostLive.Show in modules

      for module <- modules do
        assert {:error, {:redirect, %{to: @confirm_page}}} =
                 live_isolated(conn, module, session: session),
               "#{inspect(module)} does not redirect an unconfirmed user via on_mount"
      end
    end
  end

  defp has?(doc, selector), do: LazyHTML.query(doc, selector) |> Enum.any?()
end
