defmodule TraysSocialWeb.UserSettingsControllerTest do
  # Not async: the D117 mailer-failure tests swap the Mailer adapter through
  # global Application env (TraysSocial.MailerTestHelpers).
  use TraysSocialWeb.ConnCase, async: false

  import Swoosh.TestAssertions
  import TraysSocial.AccountsFixtures
  import TraysSocial.MailerTestHelpers

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.User

  setup :register_and_log_in_user

  describe "GET /users/settings" do
    test "renders settings page", %{conn: conn} do
      conn = get(conn, ~p"/users/settings")
      response = html_response(conn, 200)
      assert response =~ "Settings"
    end

    test "redirects if user is not logged in" do
      conn = build_conn()
      conn = get(conn, ~p"/users/settings")
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    @tag :skip
    @tag token_authenticated_at: DateTime.utc_now(:second) |> DateTime.add(-11, :minute)
    test "redirects if user is not in sudo mode", %{conn: conn} do
      # Skipped: LiveView replaced controller, uses simpler auth via on_mount
      conn = get(conn, ~p"/users/settings")
      assert redirected_to(conn) == ~p"/users/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must re-authenticate to access this page."
    end
  end

  describe "PUT /users/settings (change password form)" do
    test "updates the user password and resets tokens", %{conn: conn, user: user} do
      new_password_conn =
        put(conn, ~p"/users/settings", %{
          "action" => "update_password",
          "user" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(new_password_conn) == ~p"/users/settings"

      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "does not update password on invalid data", %{conn: conn} do
      old_password_conn =
        put(conn, ~p"/users/settings", %{
          "action" => "update_password",
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      response = html_response(old_password_conn, 200)
      assert response =~ "Settings"
      assert response =~ "should be at least 12 character(s)"
      assert response =~ "does not match password"

      assert get_session(old_password_conn, :user_token) == get_session(conn, :user_token)
    end
  end

  describe "PUT /users/settings (change email form)" do
    @tag :capture_log
    test "updates the user email", %{conn: conn, user: user} do
      conn =
        put(conn, ~p"/users/settings", %{
          "action" => "update_email",
          "user" => %{"email" => unique_user_email()}
        })

      assert redirected_to(conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "A link to confirm your email"

      assert Accounts.get_user_by_email(user.email)
    end

    @tag :capture_log
    test "email change flashes an error when the mailer fails", %{conn: conn} do
      conn =
        with_failing_mailer(fn ->
          put(conn, ~p"/users/settings", %{
            "action" => "update_email",
            "user" => %{"email" => unique_user_email()}
          })
        end)

      assert redirected_to(conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "couldn't send the confirmation link"

      refute Phoenix.Flash.get(conn.assigns.flash, :info)
    end

    # D123: the email-change form shares validate_email/2, so it shows the
    # neutral message too, but the signed-in user does not own the address
    # they typed, so the owner is never emailed from here.
    test "changing to a taken email shows the neutral error and sends no notice", %{
      conn: conn,
      user: user
    } do
      other = user_fixture()

      conn =
        put(conn, ~p"/users/settings", %{
          "action" => "update_email",
          "user" => %{"email" => other.email}
        })

      await_mailer_tasks()

      text = conn |> html_response(200) |> LazyHTML.from_document() |> LazyHTML.text()
      assert text =~ User.email_taken_message()
      refute text =~ "has already been taken"
      refute_email_sent()
      assert Accounts.get_user_by_email(user.email)
    end

    test "a sixth email-change attempt within the hour is rate limited with a neutral message",
         %{conn: conn} do
      Application.put_env(:trays_social, :disable_rate_limiting, false)
      on_exit(fn -> Application.put_env(:trays_social, :disable_rate_limiting, true) end)

      other = user_fixture()

      attempt = fn email ->
        put(conn, ~p"/users/settings", %{
          "action" => "update_email",
          "user" => %{"email" => email}
        })
      end

      for _ <- 1..5 do
        assert attempt.("with spaces") |> html_response(200) =~ "must have the @ sign"
      end

      limited = attempt.(other.email)
      assert redirected_to(limited) == ~p"/users/settings"

      assert Phoenix.Flash.get(limited.assigns.flash, :error) ==
               "Unable to change your email right now. Please try again later."
    end

    test "does not update email on invalid data", %{conn: conn} do
      conn =
        put(conn, ~p"/users/settings", %{
          "action" => "update_email",
          "user" => %{"email" => "with spaces"}
        })

      response = html_response(conn, 200)
      assert response =~ "Settings"
      assert response =~ "must have the @ sign and no spaces"
    end
  end

  describe "GET /users/settings/confirm-email/:token" do
    setup %{user: user} do
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{token: token, email: email}
    end

    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      conn = get(conn, ~p"/users/settings/confirm-email/#{token}")
      assert redirected_to(conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Email changed successfully"

      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)

      conn = get(conn, ~p"/users/settings/confirm-email/#{token}")

      assert redirected_to(conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Email change link is invalid or it has expired"
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      conn = get(conn, ~p"/users/settings/confirm-email/oops")
      assert redirected_to(conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Email change link is invalid or it has expired"

      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      conn = get(conn, ~p"/users/settings/confirm-email/#{token}")
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end
end
