defmodule TraysSocialWeb.API.AuthPlugTest do
  use TraysSocialWeb.ConnCase, async: true

  alias TraysSocialWeb.API.AuthPlug

  import TraysSocial.AccountsFixtures

  setup %{conn: conn} do
    conn = put_req_header(conn, "accept", "application/json")
    {:ok, conn: conn}
  end

  describe "call/2" do
    test "authenticates user with valid bearer token", %{conn: conn} do
      user = user_fixture()
      token = TraysSocial.Accounts.generate_user_api_token(user)
      encoded_token = Base.encode64(token)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{encoded_token}")
        |> AuthPlug.call([])

      assert conn.assigns.current_user.id == user.id
      refute conn.halted
    end

    test "returns 401 when no authorization header", %{conn: conn} do
      conn = AuthPlug.call(conn, [])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body) == %{"errors" => [%{"message" => "unauthorized"}]}
    end

    test "returns 401 when authorization header is not Bearer", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Basic dXNlcjpwYXNz")
        |> AuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "returns 401 for invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{Base.encode64("invalid_token")}")
        |> AuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "returns 401 for malformed base64", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer not-valid-base64!!!")
        |> AuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
    end
  end
end
