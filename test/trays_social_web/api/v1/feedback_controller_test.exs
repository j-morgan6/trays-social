defmodule TraysSocialWeb.API.V1.FeedbackControllerTest do
  use TraysSocialWeb.ConnCase, async: true

  import TraysSocial.AccountsFixtures

  alias TraysSocial.Accounts
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

    test "stores kind, app_build and screen and sets platform ios server-side", %{
      conn: conn,
      user: user
    } do
      body =
        Map.merge(@valid_body, %{"kind" => "bug", "app_build" => "372", "screen" => "Settings"})

      conn = post(conn, ~p"/api/v1/feedback", body)

      assert %{"data" => %{"id" => id, "status" => "new"}} = json_response(conn, 201)

      sub = Feedback.get_submission!(id)
      assert sub.user_id == user.id
      assert sub.kind == "bug"
      assert sub.app_build == "372"
      assert sub.screen == "Settings"
      assert sub.platform == "ios"
    end

    test "a body from a shipped build without the new keys still returns 201 with {data: {id, status}}",
         %{conn: conn} do
      conn = post(conn, ~p"/api/v1/feedback", @valid_body)

      assert %{"data" => data} = response = json_response(conn, 201)
      assert Map.keys(response) == ["data"]
      assert data |> Map.keys() |> Enum.sort() == ["id", "status"]
      assert data["status"] == "new"

      sub = Feedback.get_submission!(data["id"])
      assert sub.kind == "feedback"
      assert sub.platform == "ios"
      assert sub.app_build == nil
      assert sub.screen == nil
      assert sub.device_model == "iPhone15,3"
    end

    test "a platform of web in the body is ignored", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/feedback", Map.put(@valid_body, "platform", "web"))

      assert %{"data" => %{"id" => id}} = json_response(conn, 201)
      assert Feedback.get_submission!(id).platform == "ios"
    end

    test "stores the request user agent, not one from the body", %{conn: conn} do
      conn =
        conn
        |> put_req_header("user-agent", "TraysSocial/1.1.0 (iPhone; iOS 17.5)")
        |> post(~p"/api/v1/feedback", Map.put(@valid_body, "user_agent", "spoofed"))

      assert %{"data" => %{"id" => id}} = json_response(conn, 201)
      assert Feedback.get_submission!(id).user_agent == "TraysSocial/1.1.0 (iPhone; iOS 17.5)"
    end

    test "cuts a long user agent to 512 characters", %{conn: conn} do
      conn =
        conn
        |> put_req_header("user-agent", String.duplicate("a", 600))
        |> post(~p"/api/v1/feedback", @valid_body)

      assert %{"data" => %{"id" => id}} = json_response(conn, 201)
      assert String.length(Feedback.get_submission!(id).user_agent) == 512
    end

    test "returns 422 for an unknown kind", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/feedback", Map.put(@valid_body, "kind", "praise"))

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Enum.any?(errors, fn e -> e["field"] == "kind" end)
    end

    test "an unconfirmed user can submit" do
      user = unconfirmed_user_fixture()
      assert is_nil(user.confirmed_at)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{Accounts.generate_user_api_token(user)}")
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/v1/feedback", @valid_body)

      assert %{"data" => %{"id" => id}} = json_response(conn, 201)
      assert Feedback.get_submission!(id).user_id == user.id
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

defmodule TraysSocialWeb.API.V1.FeedbackControllerRateLimitTest do
  # Not async: this module turns on the global :disable_rate_limiting flag.
  # ExUnit runs sync modules after async ones, so this cannot race the
  # module above.
  use TraysSocialWeb.ConnCase, async: false

  # A fresh user per test, so each one gets its own Hammer bucket.
  setup :register_and_api_authenticate_user

  setup do
    Application.put_env(:trays_social, :disable_rate_limiting, false)
    on_exit(fn -> Application.put_env(:trays_social, :disable_rate_limiting, true) end)
    :ok
  end

  @valid_body %{"body" => "The save button does nothing."}

  test "the sixth submission in an hour returns 429 with the errors shape", %{conn: conn} do
    for _ <- 1..5 do
      assert %{"data" => %{"id" => _}} =
               conn |> post(~p"/api/v1/feedback", @valid_body) |> json_response(201)
    end

    limited = post(conn, ~p"/api/v1/feedback", @valid_body)

    assert json_response(limited, 429) == %{"errors" => [%{"message" => "too many requests"}]}
    assert get_resp_header(limited, "retry-after") == ["3600"]
  end
end
