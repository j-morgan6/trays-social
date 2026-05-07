defmodule TraysSocialWeb.API.V1.ConfirmTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.AccountsFixtures

  alias TraysSocial.Accounts
  alias TraysSocial.Repo

  describe "POST /api/v1/auth/confirm" do
    test "confirms an unconfirmed user with a valid token", %{conn: conn} do
      user = unconfirmed_user_fixture()
      assert is_nil(user.confirmed_at)

      token =
        extract_user_token(fn url_fun ->
          Accounts.deliver_user_confirmation_instructions(user, url_fun)
        end)

      conn = post(conn, ~p"/api/v1/auth/confirm", %{token: token})

      assert json_response(conn, 200) == %{"data" => %{"confirmed" => true}}
      assert Repo.get!(Accounts.User, user.id).confirmed_at
    end

    test "returns 422 with a clear error message for an invalid token", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/auth/confirm", %{token: "this-is-not-a-real-token"})

      assert %{"errors" => [%{"message" => message}]} = json_response(conn, 422)
      assert message =~ "Invalid or expired"
    end

    test "returns 422 when token field is missing", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/auth/confirm", %{})

      assert %{"errors" => [%{"message" => message}]} = json_response(conn, 422)
      assert message =~ "token"
    end

    test "returns 422 when token is an empty string", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/auth/confirm", %{token: ""})

      assert %{"errors" => [%{"message" => _}]} = json_response(conn, 422)
    end

    test "a token can only be used once", %{conn: conn} do
      user = unconfirmed_user_fixture()

      token =
        extract_user_token(fn url_fun ->
          Accounts.deliver_user_confirmation_instructions(user, url_fun)
        end)

      assert post(conn, ~p"/api/v1/auth/confirm", %{token: token})
             |> json_response(200) == %{"data" => %{"confirmed" => true}}

      # Second use of the same token is rejected — the underlying
      # confirm_user_by_token deletes the token row on success.
      conn2 = build_conn() |> post(~p"/api/v1/auth/confirm", %{token: token})
      assert json_response(conn2, 422)
    end
  end
end
