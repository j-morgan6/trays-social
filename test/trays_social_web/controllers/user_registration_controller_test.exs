defmodule TraysSocialWeb.UserRegistrationControllerTest do
  # Not async: the D117 mailer-failure tests swap the Mailer adapter through
  # global Application env (TraysSocial.MailerTestHelpers).
  use TraysSocialWeb.ConnCase, async: false

  import TraysSocial.AccountsFixtures
  import TraysSocial.MailerTestHelpers

  describe "GET /users/register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, ~p"/users/register")
      response = html_response(conn, 200)
      # Editorial sign-up: serif "Start your tray" + amber-adjacent primary
      # CTA + link back to sign-in.
      assert response =~ "Start your tray"
      assert response =~ ~p"/users/log-in"
      assert response =~ ~p"/users/register"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture()) |> get(~p"/users/register")

      assert redirected_to(conn) == ~p"/feed"
    end
  end

  describe "POST /users/register" do
    @tag :capture_log
    test "creates account and logs in automatically", %{conn: conn} do
      email = unique_user_email()

      conn =
        post(conn, ~p"/users/register", %{
          "user" => valid_user_attributes(email: email)
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/feed"
    end

    @tag :capture_log
    test "keeps the success flash when the email is sent", %{conn: conn} do
      conn =
        post(conn, ~p"/users/register", %{
          "user" => valid_user_attributes(email: unique_user_email())
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Please check your email"
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    @tag :capture_log
    test "shows an error flash but still logs in when the confirmation email fails", %{
      conn: conn
    } do
      email = unique_user_email()

      conn =
        with_failing_mailer(fn ->
          post(conn, ~p"/users/register", %{"user" => valid_user_attributes(email: email)})
        end)

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/feed"
      assert TraysSocial.Accounts.get_user_by_email(email)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "couldn't send your confirmation email"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Resend verification email"
      refute Phoenix.Flash.get(conn.assigns.flash, :error) =~ "simulated_mailer_failure"
      refute Phoenix.Flash.get(conn.assigns.flash, :info)
    end

    test "render errors for invalid data", %{conn: conn} do
      conn =
        post(conn, ~p"/users/register", %{
          "user" => %{"email" => "with spaces"}
        })

      response = html_response(conn, 200)
      # Failed POST re-renders the editorial sign-up landing.
      assert response =~ "Start your tray"
      assert response =~ "must have the @ sign and no spaces"
    end

    test "rejects registration when age confirmation checkbox is unchecked", %{conn: conn} do
      # Phoenix's checkbox component always renders a hidden `value="false"`
      # before the visible input, so an unchecked checkbox POSTs as "false"
      # rather than being absent. The missing-key path is covered by the API
      # auth controller tests; here we exercise the realistic web scenario.
      attrs = valid_user_attributes(age_confirmation: false)

      conn = post(conn, ~p"/users/register", %{"user" => attrs})

      response = html_response(conn, 200)
      assert response =~ "Start your tray"
      assert response =~ "13 or older"
      refute get_session(conn, :user_token)
    end
  end
end
