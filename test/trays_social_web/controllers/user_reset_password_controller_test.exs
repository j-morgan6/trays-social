defmodule TraysSocialWeb.UserResetPasswordControllerTest do
  # Not async (W255): the rate-limit and mailer-failure tests change global
  # Application env, and the reset email is sent from a supervised task
  # (TraysSocial.MailerTaskSupervisor) that the tests wait on.
  use TraysSocialWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import ExUnit.CaptureLog
  import Swoosh.TestAssertions
  import TraysSocial.AccountsFixtures
  import TraysSocial.MailerTestHelpers

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.UserToken
  alias TraysSocial.Repo

  @new_password "a brand new password"
  @invalid_link "The reset link is invalid or it has expired."

  # Only the token describes use this: it delivers a reset email, which would
  # otherwise sit in the test mailbox and satisfy (or break) the request-page
  # email assertions.
  defp create_reset_token(_context) do
    user = user_fixture()

    token =
      extract_user_token(fn url ->
        Accounts.deliver_user_reset_password_instructions(user, url)
      end)

    %{user: user, token: token}
  end

  defp put_reset(conn, token, params) do
    put(conn, ~p"/users/reset-password/#{token}", %{"user" => params})
  end

  defp assert_invalid_link_redirect(conn) do
    assert redirected_to(conn) == ~p"/users/log-in"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == @invalid_link
  end

  describe "GET /users/reset-password/:token" do
    setup :create_reset_token

    test "GET /users/reset-password/:token renders the set-password form for a valid token", %{
      conn: conn,
      token: token
    } do
      conn = get(conn, ~p"/users/reset-password/#{token}")
      doc = conn |> html_response(200) |> LazyHTML.from_document()

      form = LazyHTML.query(doc, "#reset-password form#reset_password_form")
      assert Enum.count(form) == 1
      assert LazyHTML.attribute(form, "action") == ["/users/reset-password/#{token}"]
      assert doc |> LazyHTML.query("input[name=_method][value=put]") |> Enum.count() == 1
      assert doc |> LazyHTML.query("input[name=_csrf_token]") |> Enum.count() == 1

      assert doc
             |> LazyHTML.query("input[type=password][autocomplete=new-password]")
             |> Enum.count() == 2

      assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]
      assert LazyHTML.text(doc) =~ "Set a new password"
      assert LazyHTML.text(doc) =~ "At least 12 characters."

      button = LazyHTML.query(doc, "#reset_password_form button[type=submit]")
      assert LazyHTML.text(button) =~ "Set new password"
    end

    test "GET with an invalid or expired token redirects to /users/log-in with a neutral error",
         %{
           conn: conn,
           user: user,
           token: token
         } do
      conn |> get(~p"/users/reset-password/not-a-real-token") |> assert_invalid_link_redirect()

      issued_at = DateTime.utc_now(:second) |> DateTime.add(-61, :minute)

      from(t in UserToken, where: t.user_id == ^user.id)
      |> Repo.update_all(set: [inserted_at: issued_at])

      build_conn() |> get(~p"/users/reset-password/#{token}") |> assert_invalid_link_redirect()
    end

    test "the link fails like an invalid one once the account is deleted", %{
      conn: conn,
      user: user,
      token: token
    } do
      Repo.delete!(user)
      conn |> get(~p"/users/reset-password/#{token}") |> assert_invalid_link_redirect()
    end

    test "POST to the token path is not routed", %{conn: conn, token: token} do
      conn = post(conn, "/users/reset-password/#{token}", %{"user" => %{}})
      assert conn.status == 404
    end
  end

  describe "PUT /users/reset-password/:token" do
    setup :create_reset_token

    test "PUT with matching passwords resets, ends other sessions and redirects to log in", %{
      conn: conn,
      user: user,
      token: token
    } do
      session_token = Accounts.generate_user_session_token(user)
      api_token = Accounts.generate_user_api_token(user)
      refresh_token = Accounts.generate_user_refresh_token(user)
      live_topic = "users_sessions:#{Base.url_encode64(session_token)}"
      TraysSocialWeb.Endpoint.subscribe(live_topic)

      conn =
        put_reset(conn, token, %{
          "password" => @new_password,
          "password_confirmation" => @new_password
        })

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Your password has been reset"
      assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]
      refute get_session(conn, :user_token)
      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_topic}

      assert Repo.all_by(UserToken, user_id: user.id) == []
      refute Accounts.get_user_by_session_token(session_token)
      refute Accounts.get_user_by_api_token(api_token)
      assert {:error, :invalid_refresh_token} = Accounts.exchange_refresh_token(refresh_token)
      assert Accounts.get_user_by_email_and_password(user.email, @new_password)

      reloaded = Repo.get!(TraysSocial.Accounts.User, user.id)
      assert reloaded.confirmed_at == user.confirmed_at
      assert reloaded.is_admin == user.is_admin
    end

    test "PUT with a mismatched confirmation re-renders with an amber field error and the token still works",
         %{conn: conn, user: user, token: token} do
      conn =
        put_reset(conn, token, %{
          "password" => @new_password,
          "password_confirmation" => "a different password"
        })

      body = html_response(conn, 200)
      doc = LazyHTML.from_document(body)

      field =
        LazyHTML.query(doc, "input#reset_password_form_password_confirmation[aria-invalid=true]")

      assert Enum.count(field) == 1
      assert LazyHTML.text(doc) =~ "does not match password"
      assert doc |> LazyHTML.query("#reset_password_form p.bg-accent\\/25") |> Enum.count() >= 1
      refute body =~ @new_password
      refute body =~ "a different password"

      assert Accounts.get_user_by_reset_password_token(token)
      assert Accounts.get_user_by_email_and_password(user.email, valid_user_password())
      assert build_conn() |> get(~p"/users/reset-password/#{token}") |> html_response(200)
    end

    test "PUT with an 11-character password re-renders with the 12-character rule", %{
      conn: conn,
      token: token
    } do
      conn =
        put_reset(conn, token, %{
          "password" => "elevenchars",
          "password_confirmation" => "elevenchars"
        })

      body = html_response(conn, 200)
      assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]
      assert body =~ "should be at least 12 character(s)"
      refute body =~ "elevenchars"
      assert Accounts.get_user_by_reset_password_token(token)
    end

    test "PUT without a confirmation field is rejected", %{conn: conn, user: user, token: token} do
      conn = put_reset(conn, token, %{"password" => @new_password})

      assert html_response(conn, 200) =~ "does not match password"
      assert Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end

    test "a second PUT with the same token is rejected", %{conn: conn, user: user, token: token} do
      params = %{"password" => @new_password, "password_confirmation" => @new_password}
      assert conn |> put_reset(token, params) |> redirected_to() == ~p"/users/log-in"

      second =
        put_reset(build_conn(), token, %{
          "password" => "another new password",
          "password_confirmation" => "another new password"
        })

      assert_invalid_link_redirect(second)
      assert Accounts.get_user_by_email_and_password(user.email, @new_password)
    end

    test "a suspended user can reset but log-in still refuses them", %{conn: conn} do
      user = suspended_user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      params = %{"password" => @new_password, "password_confirmation" => @new_password}
      assert conn |> put_reset(token, params) |> redirected_to() == ~p"/users/log-in"

      login =
        post(build_conn(), ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => @new_password}
        })

      refute get_session(login, :user_token)
      assert Phoenix.Flash.get(login.assigns.flash, :error) =~ "suspended"
    end

    test "PUT without the CSRF token is rejected", %{conn: conn, token: token} do
      conn = Plug.Conn.put_private(conn, :plug_skip_csrf_protection, false)

      assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
        put_reset(conn, token, %{
          "password" => @new_password,
          "password_confirmation" => @new_password
        })
      end

      assert Accounts.get_user_by_reset_password_token(token)
    end
  end

  # W255: the request side. Every request waits for the email task, so no
  # task outlives the test and every assertion sees the final mailbox.
  defp request_reset(conn, params) do
    conn = post(conn, ~p"/users/reset-password", params)
    await_mailer_tasks()
    conn
  end

  defp request_reset_for(conn, email), do: request_reset(conn, %{"user" => %{"email" => email}})

  defp unknown_email, do: "nobody-#{System.unique_integer([:positive])}@example.com"

  defp fresh_ip_conn(conn) do
    %{conn | remote_ip: {10, Enum.random(0..255), Enum.random(0..255), Enum.random(1..254)}}
  end

  # The page with its per-request CSRF values and the echoed email replaced,
  # so two outcomes can be compared byte for byte.
  defp normalise(body, email) do
    doc = LazyHTML.from_document(body)

    csrf =
      LazyHTML.attribute(LazyHTML.query(doc, "input[name=_csrf_token]"), "value") ++
        LazyHTML.attribute(LazyHTML.query(doc, "meta[name=csrf-token]"), "content")

    csrf
    |> Enum.uniq()
    |> Enum.reduce(body, &String.replace(&2, &1, "CSRF"))
    |> String.replace(email, "EMAIL")
  end

  defp squish(text), do: text |> String.split() |> Enum.join(" ")

  describe "GET /users/reset-password" do
    test "GET /users/reset-password renders the Reset form in the auth shell", %{conn: conn} do
      doc =
        conn |> get(~p"/users/reset-password") |> html_response(200) |> LazyHTML.from_document()

      shell = LazyHTML.query(doc, "#reset-request")
      assert shell |> LazyHTML.query("section[aria-label=Trays]") |> Enum.count() == 1
      assert LazyHTML.text(shell) =~ "Reset your password"

      form = LazyHTML.query(shell, "form#reset_request_form[action='/users/reset-password']")
      assert Enum.count(form) == 1
      assert form |> LazyHTML.query("input[name=_csrf_token]") |> Enum.count() == 1

      assert form
             |> LazyHTML.query(
               "input#reset_request_form_email[type=email][name='user[email]'][autocomplete=email]"
             )
             |> Enum.count() == 1

      assert form |> LazyHTML.query("button[type=submit].bg-accent") |> LazyHTML.text() =~
               "Send reset link"

      # The quiet way to the sign-in link form on the log-in page, and back.
      sign_in_link = LazyHTML.query(shell, "a[href='/users/log-in#sign-in-link']")
      assert LazyHTML.text(sign_in_link) =~ "Prefer a sign-in link?"

      assert shell |> LazyHTML.query("a[href='/users/log-in']") |> LazyHTML.text() =~
               "Back to log in"

      assert doc |> LazyHTML.query("[role=status]") |> Enum.count() == 0
    end

    test "GET /users/reset-password redirects a signed-in user", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      assert conn |> get(~p"/users/reset-password") |> redirected_to() == ~p"/feed"

      posted = request_reset_for(conn, unknown_email())
      assert redirected_to(posted) == ~p"/feed"
      assert_no_email_sent()
    end

    # Every Locale: the sign-in pages carry literal English copy with no
    # gettext call, and the Reset page takes the same path.
    test "the Reset page copy goes through the same path as the log-in page" do
      reset =
        File.read!("lib/trays_social_web/controllers/user_reset_password_html/new.html.heex")

      log_in = File.read!("lib/trays_social_web/controllers/user_session_html/new.html.heex")

      refute log_in =~ "gettext"
      refute reset =~ "gettext"
      assert reset =~ "Send reset link"
      assert reset =~ "If an account uses"
    end

    test "PUT and DELETE /users/reset-password are not routed", %{conn: conn} do
      assert put(conn, "/users/reset-password", %{"user" => %{"email" => "a@b.c"}}).status == 404
      assert delete(build_conn(), "/users/reset-password").status == 404
    end
  end

  describe "POST /users/reset-password" do
    test "POST with a known email sends one reset email and renders Check your email", %{
      conn: conn
    } do
      user = user_fixture()

      conn = request_reset_for(conn, user.email)

      assert_email_sent(fn email ->
        assert email.to == [{"", user.email}]
        assert email.text_body =~ "/users/reset-password/"
      end)

      assert_no_email_sent()

      doc = conn |> html_response(200) |> LazyHTML.from_document()
      assert doc |> LazyHTML.query("#reset-request h1") |> LazyHTML.text() =~ "Check your email"

      status = LazyHTML.query(doc, "#reset-request #reset-sent[role=status]")

      assert squish(LazyHTML.text(status)) ==
               "If an account uses #{user.email}, a reset link is on its way. It works for one hour."

      resend = LazyHTML.query(doc, "form#reset_resend_form[action='/users/reset-password']")
      hidden = LazyHTML.query(resend, "input[type=hidden][name='user[email]']")
      assert LazyHTML.attribute(hidden, "value") == [user.email]
      assert resend |> LazyHTML.query("button[type=submit]") |> LazyHTML.text() =~ "Resend link"

      assert doc |> LazyHTML.query("a[href='/users/log-in']") |> LazyHTML.text() =~
               "Back to log in"

      assert doc |> LazyHTML.query("form#reset_request_form") |> Enum.count() == 0
    end

    test "POST with an unknown email renders the identical Check your email page and sends nothing",
         %{conn: conn} do
      user = user_fixture()
      known = request_reset_for(conn, user.email)
      assert_email_sent(to: user.email)

      email = unknown_email()
      unknown = request_reset_for(build_conn(), email)
      assert_no_email_sent()

      assert known.status == 200
      assert unknown.status == 200
      assert html_response(unknown, 200) =~ email
      assert normalise(known.resp_body, user.email) == normalise(unknown.resp_body, email)
    end

    test "POST again inside the per-email window renders Check your email and sends no second email",
         %{conn: conn} do
      Application.put_env(:trays_social, :disable_rate_limiting, false)
      on_exit(fn -> Application.put_env(:trays_social, :disable_rate_limiting, true) end)

      user = user_fixture()
      conn = fresh_ip_conn(conn)

      first = request_reset_for(conn, user.email)
      assert_email_sent(subject: "Reset your Trays password")

      # Resend posts what the page's own Resend form carries.
      [resent] =
        first.resp_body
        |> LazyHTML.from_document()
        |> LazyHTML.query("form#reset_resend_form input[type=hidden][name='user[email]']")
        |> LazyHTML.attribute("value")

      assert resent == user.email

      second = request_reset_for(conn, resent)
      assert_no_email_sent()

      assert second.status == 200
      assert normalise(second.resp_body, user.email) == normalise(first.resp_body, user.email)
    end

    test "POST when the mailer fails still renders Check your email", %{conn: conn} do
      user = user_fixture()
      email = unknown_email()
      baseline = request_reset_for(build_conn(), email)

      with_failing_mailer(fn ->
        log =
          capture_log(fn ->
            failed = request_reset_for(conn, user.email)
            send(self(), {:failed_response, failed.status, failed.resp_body})
          end)

        assert_received {:failed_response, 200, body}
        assert normalise(body, user.email) == normalise(baseline.resp_body, email)
        assert log =~ "email delivery failed"
        refute log =~ "/users/reset-password/"
      end)

      assert_no_email_sent()
    end

    test "POST with a blank email re-renders the form with an amber field error", %{conn: conn} do
      for params <- [%{"user" => %{"email" => ""}}, %{"user" => %{"email" => "   "}}, %{}] do
        doc = conn |> request_reset(params) |> html_response(200) |> LazyHTML.from_document()

        form = LazyHTML.query(doc, "#reset-request form#reset_request_form")
        input = LazyHTML.query(form, "input#reset_request_form_email[aria-invalid=true]")
        assert Enum.count(input) == 1

        error = LazyHTML.query(form, "p.bg-accent\\/25")
        assert LazyHTML.text(error) =~ "Enter your email address."

        assert doc |> LazyHTML.query("#reset-sent") |> Enum.count() == 0
      end

      assert_no_email_sent()
    end

    test "POST trims the email and escapes it when echoing it", %{conn: conn} do
      user = user_fixture()
      padded = "  " <> String.upcase(user.email) <> " "

      doc =
        conn |> request_reset_for(padded) |> html_response(200) |> LazyHTML.from_document()

      assert_email_sent(to: user.email)

      assert doc |> LazyHTML.query("#reset-sent strong") |> LazyHTML.text() ==
               String.upcase(user.email)

      hostile = "<script>alert(1)</script>@example.com"
      body = build_conn() |> request_reset_for(hostile) |> html_response(200)
      refute body =~ "<script>alert(1)"
      assert body =~ "&lt;script&gt;alert(1)&lt;/script&gt;@example.com"
      assert_no_email_sent()
    end

    test "POST with a very long email keeps it inside the status panel", %{conn: conn} do
      long = String.duplicate("a", 160) <> "@example.com"

      doc = conn |> request_reset_for(long) |> html_response(200) |> LazyHTML.from_document()

      strong = LazyHTML.query(doc, "#reset-sent strong.break-all")
      assert LazyHTML.text(strong) == long
    end
  end

  describe "request logging" do
    test "skips the endpoint request log for the token path only" do
      alias TraysSocialWeb.Endpoint

      refute Endpoint.request_log_level(%Plug.Conn{path_info: ["users", "reset-password", "t"]})

      assert Endpoint.request_log_level(%Plug.Conn{path_info: ["users", "reset-password"]}) ==
               :info

      assert Endpoint.request_log_level(%Plug.Conn{path_info: ["users", "log-in"]}) == :info
    end
  end
end
