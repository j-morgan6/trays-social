defmodule TraysSocialWeb.UserResetPasswordControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  import Ecto.Query, only: [from: 2]
  import TraysSocial.AccountsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.Accounts.UserToken
  alias TraysSocial.Repo

  @new_password "a brand new password"
  @invalid_link "The reset link is invalid or it has expired."

  setup do
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
