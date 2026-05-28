defmodule TraysSocialWeb.API.V1.FeedbackControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  alias TraysSocial.Feedback

  @valid_body %{
    "subject" => "Test subject",
    "body" => "I really like the new shell.",
    "app_version" => "1.0.0",
    "os_version" => "17.5",
    "device_model" => "iPhone15,3"
  }

  setup :register_and_api_authenticate_user

  describe "POST /api/v1/feedback" do
    test "stores a submission and returns 201", %{conn: conn, user: user} do
      conn = post(conn, ~p"/api/v1/feedback", @valid_body)

      assert %{"data" => %{"id" => id, "status" => "new"}} = json_response(conn, 201)
      assert is_integer(id)

      sub = Feedback.get_submission!(id)
      assert sub.user_id == user.id
      assert sub.body == "I really like the new shell."
      assert sub.app_version == "1.0.0"
    end

    test "returns 422 when body is missing", %{conn: conn} do
      body = Map.delete(@valid_body, "body")
      conn = post(conn, ~p"/api/v1/feedback", body)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Enum.any?(errors, fn e -> e["field"] == "body" end)
    end

    test "returns 422 when body is whitespace-only", %{conn: conn} do
      body = %{@valid_body | "body" => "   \n  "}
      conn = post(conn, ~p"/api/v1/feedback", body)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Enum.any?(errors, fn e -> e["field"] == "body" end)
    end

    test "returns 422 when body exceeds 5000 chars", %{conn: conn} do
      body = %{@valid_body | "body" => String.duplicate("a", 5001)}
      conn = post(conn, ~p"/api/v1/feedback", body)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Enum.any?(errors, fn e -> e["field"] == "body" end)
    end

    test "returns 401 when unauthenticated" do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/v1/feedback", @valid_body)

      assert json_response(conn, 401)
    end
  end
end
