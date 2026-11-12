defmodule TraysSocialWeb.UserConfirmationControllerTest do
  # Not async: the mailer-failure and rate-limit tests flip global
  # Application env (the Mailer adapter and :disable_rate_limiting), and
  # Hammer's buckets are process-global.
  use TraysSocialWeb.ConnCase, async: false

  import ExUnit.CaptureLog
  import Swoosh.TestAssertions
  import TraysSocial.AccountsFixtures
  import TraysSocial.MailerTestHelpers

  describe "POST /users/confirmation/resend" do
    test "resend delivers a confirmation email to an unconfirmed user", %{conn: conn} do
      user = unconfirmed_user_fixture()

      conn = conn |> log_in_user(user) |> post(~p"/users/confirmation/resend")

      assert redirected_to(conn) == ~p"/users/confirm-required"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "new confirmation link has been sent"

      assert_email_sent(fn email ->
        assert email.to == [{"", user.email}]
        assert email.subject == "Confirm your Trays account"
        assert email.text_body =~ "/users/confirm/"
      end)
    end

    test "resend surfaces a mailer failure as an error flash", %{conn: conn} do
      user = unconfirmed_user_fixture()

      {conn, _log} =
        with_failing_mailer(fn ->
          with_log(fn ->
            conn |> log_in_user(user) |> post(~p"/users/confirmation/resend")
          end)
        end)

      assert redirected_to(conn) == ~p"/users/confirm-required"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "couldn't send"
      refute Phoenix.Flash.get(conn.assigns.flash, :info)
    end

    test "resend for an already-confirmed user does not send and flashes a notice",
         %{conn: conn} do
      user = user_fixture()

      conn = conn |> log_in_user(user) |> post(~p"/users/confirmation/resend")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "already confirmed"
      assert_no_email_sent()
    end

    test "resend from a logged-out visitor sends nothing and reveals nothing", %{conn: conn} do
      conn = post(conn, ~p"/users/confirmation/resend")

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "If your email needs confirmation, a new link has been sent."

      assert_no_email_sent()
    end
  end

  describe "POST /users/confirmation/resend with rate limiting enabled" do
    setup do
      Application.put_env(:trays_social, :disable_rate_limiting, false)
      on_exit(fn -> Application.put_env(:trays_social, :disable_rate_limiting, true) end)
      :ok
    end

    test "resend is rate limited and says so" do
      # Fresh user and IP so Hammer's global buckets from other tests
      # cannot leak in.
      user = unconfirmed_user_fixture()
      ip = {10, Enum.random(0..255), Enum.random(0..255), Enum.random(0..255)}

      first =
        %{build_conn() | remote_ip: ip}
        |> log_in_user(user)
        |> post(~p"/users/confirmation/resend")

      assert Phoenix.Flash.get(first.assigns.flash, :info) =~
               "new confirmation link has been sent"

      assert_email_sent(subject: "Confirm your Trays account")

      second =
        %{build_conn() | remote_ip: ip}
        |> log_in_user(user)
        |> post(~p"/users/confirmation/resend")

      assert redirected_to(second) == ~p"/users/confirm-required"

      assert Phoenix.Flash.get(second.assigns.flash, :error) ==
               "Please wait before requesting another confirmation email."

      assert_no_email_sent()
    end
  end

  # W203: the old warning banner is gone; an unconfirmed user is gated to
  # the confirm page instead, and confirming lifts the gate.
  describe "GET /users/confirm/:token lifts the confirmation gate" do
    test "following the emailed link lets the user into the app" do
      user = unconfirmed_user_fixture()

      assert redirected_to(signed_in_get(user, ~p"/home")) == ~p"/users/confirm-required"

      token =
        extract_user_token(fn url_fun ->
          TraysSocial.Accounts.deliver_user_confirmation_instructions(user, url_fun)
        end)

      conn = build_conn() |> log_in_user(user) |> get(~p"/users/confirm/#{token}")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Email confirmed successfully."

      assert html_response(signed_in_get(user, ~p"/home"), 200)

      confirm_page = signed_in_get(user, ~p"/users/confirm-required")
      assert redirected_to(confirm_page) == TraysSocialWeb.UserAuth.signed_in_path(confirm_page)
    end
  end

  # W252: the verify-email gate shares the WebAuth shell; the mint
  # "Check your email" box and the gate's ids and routes are unchanged.
  describe "GET /users/confirm-required in the sign-in shell" do
    test "renders the brand panel, the check-your-email box and the ways out" do
      user = unconfirmed_user_fixture()

      doc =
        user
        |> signed_in_get(~p"/users/confirm-required")
        |> html_response(200)
        |> LazyHTML.from_document()

      assert doc |> LazyHTML.query("#confirm-required section[aria-label=Trays]") |> Enum.count() ==
               1

      status = LazyHTML.query(doc, "#confirm-required [role=status].bg-mint-tint")
      assert LazyHTML.text(status) =~ "Check your email"
      assert LazyHTML.text(status) =~ user.email

      resend =
        LazyHTML.query(doc, "form#resend-confirmation-form[action='/users/confirmation/resend']")

      assert resend |> LazyHTML.query("input[name='_csrf_token']") |> Enum.count() == 1
      assert resend |> LazyHTML.query("button.bg-accent") |> Enum.count() == 1

      assert doc
             |> LazyHTML.query("a#confirm-required-change-email[href='/users/settings']")
             |> Enum.count() == 1

      assert doc
             |> LazyHTML.query("a#confirm-required-log-out[data-method=delete]")
             |> Enum.count() == 1
    end
  end

  defp signed_in_get(user, path), do: build_conn() |> log_in_user(user) |> get(path)
end
