defmodule TraysSocialWeb.API.V1.FallbackControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  alias TraysSocialWeb.API.V1.FallbackController

  setup %{conn: conn} do
    conn = put_req_header(conn, "accept", "application/json")
    {:ok, conn: conn}
  end

  describe "call/2 with changeset errors" do
    test "renders changeset errors as JSON", %{conn: conn} do
      changeset =
        %TraysSocial.Accounts.User{}
        |> Ecto.Changeset.cast(%{email: ""}, [:email])
        |> Ecto.Changeset.validate_required([:email])

      conn = FallbackController.call(conn, {:error, changeset})

      assert conn.status == 422
      body = Jason.decode!(conn.resp_body)
      assert %{"errors" => errors} = body
      assert Enum.any?(errors, fn e -> e["field"] == "email" end)
    end
  end

  describe "call/2 with error tuples" do
    test "renders 404 for :not_found", %{conn: conn} do
      conn = FallbackController.call(conn, {:error, :not_found})

      assert conn.status == 404
      assert Jason.decode!(conn.resp_body) == %{"errors" => [%{"message" => "not found"}]}
    end

    test "renders 401 for :unauthorized", %{conn: conn} do
      conn = FallbackController.call(conn, {:error, :unauthorized})

      assert conn.status == 401
      assert Jason.decode!(conn.resp_body) == %{"errors" => [%{"message" => "unauthorized"}]}
    end

    test "renders 403 for :forbidden", %{conn: conn} do
      conn = FallbackController.call(conn, {:error, :forbidden})

      assert conn.status == 403
      assert Jason.decode!(conn.resp_body) == %{"errors" => [%{"message" => "forbidden"}]}
    end
  end
end
