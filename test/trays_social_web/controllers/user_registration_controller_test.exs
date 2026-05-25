defmodule TraysSocialWeb.UserRegistrationControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.AccountsFixtures

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

      assert redirected_to(conn) == ~p"/"
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
      assert redirected_to(conn) == ~p"/"
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
