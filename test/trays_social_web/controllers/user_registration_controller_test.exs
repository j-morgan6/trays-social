defmodule TraysSocialWeb.UserRegistrationControllerTest do
  # Not async: the D117 mailer-failure tests swap the Mailer adapter through
  # global Application env (TraysSocial.MailerTestHelpers).
  use TraysSocialWeb.ConnCase, async: false

  import Swoosh.TestAssertions
  import TraysSocial.AccountsFixtures
  import TraysSocial.MailerTestHelpers

  alias TraysSocial.Accounts.User

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

    # W252: field errors sit in place under their field as the amber
    # field error, the form keeps its action and param names, and the
    # restyled shell (brand panel, amber Create account) renders.
    test "invalid registration shows errors", %{conn: conn} do
      doc =
        conn
        |> post(~p"/users/register", %{"user" => %{"email" => "with spaces", "username" => "x"}})
        |> html_response(200)
        |> LazyHTML.from_document()

      assert doc |> LazyHTML.query("#create-account section[aria-label=Trays]") |> Enum.count() ==
               1

      form = LazyHTML.query(doc, "#create-account form[action='/users/register']")
      assert form |> LazyHTML.query("input[name='_csrf_token']") |> Enum.count() == 1

      for name <- ~w(username email password password_confirmation age_confirmation) do
        assert form |> LazyHTML.query("input[name='user[#{name}]']") |> Enum.count() >= 1
      end

      email_field = LazyHTML.query(form, "input#user_email[aria-invalid=true]")
      assert Enum.count(email_field) == 1

      assert form |> LazyHTML.query("p.bg-accent\\/25") |> LazyHTML.text() =~
               "must have the @ sign"

      assert form |> LazyHTML.query("button[type=submit].bg-accent") |> LazyHTML.text() =~
               "Create account"
    end

    test "a failed registration never echoes the password", %{conn: conn} do
      html =
        conn
        |> post(~p"/users/register", %{
          "user" => %{
            "email" => "with spaces",
            "password" => "typed-secret-password",
            "password_confirmation" => "typed-secret-password"
          }
        })
        |> html_response(200)

      refute html =~ "typed-secret-password"
      doc = LazyHTML.from_document(html)
      password = LazyHTML.query(doc, "input#user_password")
      assert Enum.count(password) == 1
      assert LazyHTML.attribute(password, "value") == []
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

  # D123: a taken email must not confirm that the address has an account.
  describe "POST /users/register with a taken email" do
    defp fresh_ip_conn do
      %{
        build_conn()
        | remote_ip: {10, Enum.random(0..255), Enum.random(0..255), Enum.random(1..254)}
      }
    end

    defp register_taken(conn, email, extra \\ %{}) do
      attrs = Map.merge(valid_user_attributes(email: email), extra)
      conn = post(conn, ~p"/users/register", %{"user" => attrs})
      await_mailer_tasks()
      conn
    end

    defp email_error_text(conn) do
      conn
      |> html_response(200)
      |> LazyHTML.from_document()
      |> LazyHTML.query("#create-account form p.bg-accent\\/25")
      |> LazyHTML.text()
    end

    test "a taken email shows the neutral error and emails the owner once", %{conn: conn} do
      owner = user_fixture()

      conn = register_taken(conn, owner.email)

      text = email_error_text(conn)
      assert text =~ User.email_taken_message()
      refute text =~ "has already been taken"
      refute get_session(conn, :user_token)

      assert_email_sent(fn email ->
        assert email.to == [{"", owner.email}]
        assert email.subject == "Someone tried to create a Trays account with your email"
      end)

      refute_email_sent()
    end

    test "a taken email in another case still sends the notice to the stored address", %{
      conn: conn
    } do
      owner = user_fixture()

      conn = register_taken(conn, String.upcase(owner.email))

      assert email_error_text(conn) =~ User.email_taken_message()
      assert_email_sent(fn email -> assert email.to == [{"", owner.email}] end)
    end

    test "a taken email with an invalid password shows both errors and sends one notice", %{
      conn: conn
    } do
      owner = user_fixture()

      conn = register_taken(conn, owner.email, %{password: "short"})

      text = email_error_text(conn)
      assert text =~ User.email_taken_message()
      assert text =~ "should be at least"
      assert_email_sent(fn email -> assert email.to == [{"", owner.email}] end)
      refute_email_sent()
    end

    test "a second taken-email attempt within the hour sends no second notice" do
      Application.put_env(:trays_social, :disable_rate_limiting, false)
      on_exit(fn -> Application.put_env(:trays_social, :disable_rate_limiting, true) end)

      owner = user_fixture()

      first = register_taken(fresh_ip_conn(), owner.email)
      assert email_error_text(first) =~ User.email_taken_message()
      assert_email_sent(fn email -> assert email.to == [{"", owner.email}] end)

      second = register_taken(fresh_ip_conn(), owner.email)
      assert email_error_text(second) =~ User.email_taken_message()
      refute_email_sent()

      # The page is the same whether or not a notice went out.
      assert email_error_text(first) == email_error_text(second)
    end

    test "a taken username keeps has already been taken and sends no notice", %{conn: conn} do
      owner = user_fixture()

      conn =
        register_taken(conn, unique_user_email(), %{username: owner.username})

      assert email_error_text(conn) =~ "has already been taken"
      refute_email_sent()
    end

    test "a blank email still shows can't be blank", %{conn: conn} do
      conn = register_taken(conn, "")

      text = email_error_text(conn)
      assert text =~ "can't be blank"
      refute text =~ User.email_taken_message()
      refute_email_sent()
    end
  end

  describe "POST /users/register with rate limiting enabled" do
    setup do
      Application.put_env(:trays_social, :disable_rate_limiting, false)
      on_exit(fn -> Application.put_env(:trays_social, :disable_rate_limiting, true) end)
      :ok
    end

    # W252: the rate limit still applies after the restyle, and its neutral
    # D46 message shows once, as the amber callout above the button rather
    # than as a toast.
    test "a rate-limited registration shows the amber callout in place" do
      ip = {10, Enum.random(0..255), Enum.random(0..255), Enum.random(0..255)}

      attempt = fn ->
        post(%{build_conn() | remote_ip: ip}, ~p"/users/register", %{"user" => %{}})
      end

      for _ <- 1..5, do: attempt.()
      conn = attempt.()

      doc = conn |> html_response(200) |> LazyHTML.from_document()
      callout = LazyHTML.query(doc, "#create-account #registration-error[role=alert]")
      assert LazyHTML.text(callout) =~ "Unable to create your account right now"
      assert doc |> LazyHTML.query("#flash-error") |> Enum.count() == 0
      refute get_session(conn, :user_token)
    end
  end
end
