defmodule TraysSocialWeb.UserSessionControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.AccountsFixtures
  alias TraysSocial.Accounts

  setup do
    %{unconfirmed_user: unconfirmed_user_fixture(), user: user_fixture()}
  end

  describe "GET /users/log-in" do
    # W262: people who cannot sign in cannot use /feedback.
    test "the log-in page shows the support address for sign-in trouble", %{conn: conn} do
      doc = conn |> get(~p"/users/log-in") |> html_response(200) |> LazyHTML.from_document()

      line = LazyHTML.query(doc, "#log-in p#log-in-support")
      assert LazyHTML.text(line) =~ "Trouble signing in?"
      assert line |> LazyHTML.query(~s(a[href="mailto:support@trays.app"])) |> Enum.count() == 1

      # The W252 form ids and the reset link are untouched.
      assert doc |> LazyHTML.query("form#login_form_password") |> Enum.count() == 1
      assert doc |> LazyHTML.query("form#login_form_magic") |> Enum.count() == 1
      assert doc |> LazyHTML.query(~s(a[href="/users/reset-password"])) |> Enum.count() == 1
    end

    test "renders login page", %{conn: conn} do
      conn = get(conn, ~p"/users/log-in")
      response = html_response(conn, 200)
      # WebAuth sign-in: heading, amber Log in, link to Create account.
      assert response =~ "Welcome back"
      assert response =~ ~p"/users/register"
      assert response =~ "Log in"
    end

    # W252: the WebAuth split panel. Asserts each restyled section and that
    # the form keeps its ids, action and param names (the visual pass must
    # not change what the controller receives).
    test "log-in page renders the form", %{conn: conn} do
      doc = conn |> get(~p"/users/log-in") |> html_response(200) |> LazyHTML.from_document()

      # Brand panel beside the form: lockup, eyebrow, headline, three tiles.
      panel = LazyHTML.query(doc, "#log-in section[aria-label=Trays]")
      assert LazyHTML.text(panel) =~ "Recipes worth keeping"
      assert LazyHTML.text(panel) =~ "A quiet place to cook."
      assert panel |> LazyHTML.query("li") |> Enum.count() == 3
      assert panel |> LazyHTML.query("img[src='/images/logo-on-dark.svg']") |> Enum.count() == 1

      # The password form posts to the same route with the same params.
      form = LazyHTML.query(doc, "form#login_form_password[action='/users/log-in']")
      assert Enum.count(form) == 1
      assert form |> LazyHTML.query("input[name='_csrf_token']") |> Enum.count() == 1

      assert form
             |> LazyHTML.query("input#login_form_password_email[name='user[email]']")
             |> Enum.count() == 1

      assert form
             |> LazyHTML.query("input#login_form_password_password[name='user[password]']")
             |> Enum.count() == 1

      # Keep me logged in is a checkbox sending remember_me=true, on by default.
      remember =
        LazyHTML.query(form, "input[type=checkbox][name='user[remember_me]'][value=true]")

      assert LazyHTML.attribute(remember, "checked") == [""]

      # Amber primary button; no error callout until a failed attempt.
      assert form |> LazyHTML.query("button[type=submit].bg-accent") |> LazyHTML.text() =~
               "Log in"

      assert doc |> LazyHTML.query("#login-error") |> Enum.count() == 0

      # W255: Forgot password? opens the Reset page. The sign-in link form
      # stays on the page, hidden until it is the :target (the Reset page
      # links to it), so it needs no JavaScript.
      assert form |> LazyHTML.query("a[href='/users/reset-password']") |> LazyHTML.text() =~
               "Forgot password?"

      assert doc |> LazyHTML.query("a[href='#sign-in-link']") |> Enum.count() == 0

      section = LazyHTML.query(doc, "section#sign-in-link.hidden.target\\:block")
      assert section |> LazyHTML.query("form#login_form_magic") |> Enum.count() == 1
    end

    test "the log-in page links Forgot password? to /users/reset-password", %{conn: conn} do
      doc = conn |> get(~p"/users/log-in") |> html_response(200) |> LazyHTML.from_document()

      [href] =
        doc
        |> LazyHTML.query("form#login_form_password a")
        |> Enum.filter(&(LazyHTML.text(&1) =~ "Forgot password?"))
        |> Enum.flat_map(&LazyHTML.attribute(&1, "href"))

      assert href == ~p"/users/reset-password"
      assert build_conn() |> get(href) |> html_response(200) =~ "Reset your password"
    end

    # W255: HEEx comments never render, so the developer note is checked in
    # the template source rather than through a request.
    test "the log-in template no longer says the web has no password reset" do
      source = File.read!("lib/trays_social_web/controllers/user_session_html/new.html.heex")

      refute source =~ "There is no\n     password reset on the web"
      refute source =~ "no password reset on the web"
      refute source =~ "No reset flow exists on the web"
      assert source =~ ~s{"Forgot password?"\n     opens the Reset page (W255)}
    end

    test "renders login page with email filled in (sudo mode)", %{conn: conn, user: user} do
      html =
        conn
        |> log_in_user(user)
        |> get(~p"/users/log-in")
        |> html_response(200)

      # Editorial reauthenticate copy.
      assert html =~ "Reauthenticate"
      assert html =~ "Confirm your password"
      refute html =~ "Register"

      # The magic-link form is now nested inside a <details>; the email
      # field is still pre-filled when in sudo mode.
      assert html =~
               ~s(<input type="email" name="user[email]" id="login_form_magic_email" value="#{user.email}")

      # W255: the Reset page redirects signed-in users, so in sudo mode
      # Forgot password? still opens the sign-in link form on this page.
      doc = LazyHTML.from_document(html)

      assert doc |> LazyHTML.query("a[href='#sign-in-link']") |> LazyHTML.text() =~
               "Forgot password?"

      assert doc |> LazyHTML.query("a[href='/users/reset-password']") |> Enum.count() == 0
    end

    test "renders login page (email + password)", %{conn: conn} do
      conn = get(conn, ~p"/users/log-in?mode=password")
      response = html_response(conn, 200)
      assert response =~ "Welcome back"
      assert response =~ ~p"/users/register"
      assert response =~ "Log in"
    end
  end

  describe "GET /users/log-in/:token" do
    test "renders confirmation page for unconfirmed user", %{conn: conn, unconfirmed_user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      conn = get(conn, ~p"/users/log-in/#{token}")
      # Editorial confirm copy.
      assert html_response(conn, 200) =~ "Confirm and stay signed in"
    end

    # W252: the confirm page shares the WebAuth shell, and a long email in
    # its heading wraps instead of overflowing at phone width.
    test "renders the confirm page in the sign-in shell with a wrapping heading", %{conn: conn} do
      user = user_fixture(email: String.duplicate("a", 60) <> "@example.com")

      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      doc =
        conn |> get(~p"/users/log-in/#{token}") |> html_response(200) |> LazyHTML.from_document()

      panel = LazyHTML.query(doc, "#confirm-sign-in section[aria-label=Trays]")
      assert LazyHTML.text(panel) =~ "A quiet place to cook."

      assert doc |> LazyHTML.query("#confirm-sign-in h1.break-words") |> LazyHTML.text() =~
               user.email

      form = LazyHTML.query(doc, "form#login_form[action='/users/log-in']")
      assert form |> LazyHTML.query("input[name='user[token]'][type=hidden]") |> Enum.count() == 1

      assert form
             |> LazyHTML.query("button.bg-accent[name='user[remember_me]'][value=true]")
             |> Enum.count() == 1
    end

    test "renders login page for confirmed user", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      conn = get(conn, ~p"/users/log-in/#{token}")
      html = html_response(conn, 200)
      refute html =~ "Confirm my account"
      # Confirmed user lands on the editorial confirm page, which shows
      # the user's email and a "Keep me signed in" CTA.
      assert html =~ user.email
      assert html =~ "Keep me signed in"
    end

    test "raises error for invalid token", %{conn: conn} do
      conn = get(conn, ~p"/users/log-in/invalid-token")
      assert redirected_to(conn) == ~p"/users/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Magic link is invalid or it has expired."
    end
  end

  describe "POST /users/log-in - email and password" do
    test "logs the user in", %{conn: conn, user: user} do
      user = set_password(user)

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/feed"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/feed")
      response = html_response(conn, 200)
      assert response =~ user.username
      assert response =~ ~p"/users/settings"
      assert response =~ ~p"/users/log-out"
    end

    test "logs the user in with remember me", %{conn: conn, user: user} do
      user = set_password(user)

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_trays_social_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/feed"
    end

    test "logs the user in with return to", %{conn: conn, user: user} do
      user = set_password(user)

      conn =
        conn
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "emits error message with invalid credentials", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in?mode=password", %{
          "user" => %{"email" => user.email, "password" => "invalid_password"}
        })

      response = html_response(conn, 200)
      # Failed credential POST re-renders the sign-in page with the amber
      # callout above the button, and the toast group leaves it out so the
      # message shows once.
      assert response =~ "Welcome back"
      doc = LazyHTML.from_document(response)
      callout = LazyHTML.query(doc, "#login_form_password #login-error[role=alert]")
      assert LazyHTML.text(callout) =~ "Invalid email or password"
      assert doc |> LazyHTML.query("#flash-error") |> Enum.count() == 0
      # Generic copy: nothing says whether the account exists.
      refute response =~ "not found"
      refute response =~ "no account"
    end

    test "a failed log-in keeps the remember-me choice and never echoes the password", %{
      conn: conn,
      user: user
    } do
      doc =
        conn
        |> post(~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => "wrong-password-typed",
            "remember_me" => "false"
          }
        })
        |> html_response(200)
        |> LazyHTML.from_document()

      remember = LazyHTML.query(doc, "input[type=checkbox][name='user[remember_me]']")
      assert Enum.count(remember) == 1
      assert LazyHTML.attribute(remember, "checked") == []

      password = LazyHTML.query(doc, "input#login_form_password_password")
      assert Enum.count(password) == 1
      assert LazyHTML.attribute(password, "value") == []
      refute LazyHTML.to_html(doc) =~ "wrong-password-typed"
    end

    test "a sign-in link request shows the check-your-email box in place", %{
      conn: conn,
      user: user
    } do
      conn = post(conn, ~p"/users/log-in", %{"user" => %{"email" => user.email}})
      assert redirected_to(conn) == ~p"/users/log-in"

      doc =
        conn
        |> recycle()
        |> get(~p"/users/log-in")
        |> html_response(200)
        |> LazyHTML.from_document()

      status = LazyHTML.query(doc, "#log-in [role=status]")
      assert LazyHTML.text(status) =~ "If your email is in our system"
      assert doc |> LazyHTML.query("#flash-info") |> Enum.count() == 0
    end

    test "refuses suspended user and redirects to log-in with flash", %{conn: conn} do
      user = suspended_user_fixture() |> set_password()

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      refute get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "suspended"
    end
  end

  describe "POST /users/log-in - magic link" do
    test "sends magic link email when user exists", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      assert TraysSocial.Repo.get_by!(Accounts.UserToken, user_id: user.id).context == "login"
    end

    test "logs the user in", %{conn: conn, user: user} do
      {token, _hashed_token} = generate_user_magic_link_token(user)

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => token}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/feed"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/feed")
      response = html_response(conn, 200)
      assert response =~ user.username
      assert response =~ ~p"/users/settings"
      assert response =~ ~p"/users/log-out"
    end

    @tag :skip
    test "confirms unconfirmed user", %{conn: conn, unconfirmed_user: user} do
      {token, _hashed_token} = generate_user_magic_link_token(user)
      refute user.confirmed_at

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => token},
          "_action" => "confirmed"
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/feed"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "User confirmed successfully."

      assert Accounts.get_user!(user.id).confirmed_at

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/feed")
      response = html_response(conn, 200)
      assert response =~ user.username
      assert response =~ ~p"/users/settings"
      assert response =~ ~p"/users/log-out"
    end

    test "emits error message when magic link is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => "invalid"}
        })

      assert html_response(conn, 200) =~ "The link is invalid or it has expired."
    end
  end

  describe "DELETE /users/log-out" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
