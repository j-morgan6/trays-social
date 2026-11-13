defmodule TraysSocialWeb.API.V1.PasswordResetTest do
  # Not async: the mailer-failure and rate-limit tests change global
  # Application env, and the reset email is sent from a supervised task
  # (TraysSocial.MailerTaskSupervisor) that the tests wait on.
  use TraysSocialWeb.ConnCase, async: false

  import ExUnit.CaptureLog
  import Swoosh.TestAssertions
  import TraysSocial.AccountsFixtures
  import TraysSocial.MailerTestHelpers

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  # Every request waits for the email task, so no task outlives the test and
  # every assertion sees the final mailbox.
  defp request_reset(conn, params) do
    conn = post(conn, ~p"/api/v1/auth/reset-password", params)
    await_mailer_tasks()
    conn
  end

  defp unknown_email, do: "nobody-#{System.unique_integer([:positive])}@example.com"

  defp fresh_ip_conn(conn) do
    %{conn | remote_ip: {10, Enum.random(0..255), Enum.random(0..255), Enum.random(1..254)}}
  end

  describe "POST /api/v1/auth/reset-password" do
    test "POST /api/v1/auth/reset-password returns the same 202 body for a known and an unknown email",
         %{conn: conn} do
      user = user_fixture()

      known = request_reset(conn, %{"email" => user.email})

      assert_email_sent(fn email ->
        assert email.to == [{"", user.email}]
        assert email.text_body =~ "/users/reset-password/"
      end)

      unknown = request_reset(build_conn(), %{"email" => unknown_email()})
      assert_no_email_sent()

      assert known.status == 202
      assert unknown.status == 202
      assert known.resp_body == unknown.resp_body

      assert %{"data" => %{"message" => message}} = Jason.decode!(known.resp_body)
      assert message =~ "if an account exists"
    end

    test "a second request for the same email inside the window returns 202 and sends no second email",
         %{conn: conn} do
      Application.put_env(:trays_social, :disable_rate_limiting, false)
      on_exit(fn -> Application.put_env(:trays_social, :disable_rate_limiting, true) end)

      user = user_fixture()
      conn = fresh_ip_conn(conn)

      first = request_reset(conn, %{"email" => user.email})
      assert_email_sent(subject: "Reset your Trays password")

      second = request_reset(conn, %{"email" => user.email})
      assert_no_email_sent()

      assert second.status == 202
      assert second.resp_body == first.resp_body
    end

    test "returns 202 with the same body when the mailer fails", %{conn: conn} do
      user = user_fixture()
      baseline = request_reset(build_conn(), %{"email" => unknown_email()})

      with_failing_mailer(fn ->
        log =
          capture_log(fn ->
            failed = request_reset(conn, %{"email" => user.email})
            send(self(), {:failed_response, failed.status, failed.resp_body})
          end)

        assert_received {:failed_response, 202, body}
        assert body == baseline.resp_body
        assert log =~ "email delivery failed"
        refute log =~ "/users/reset-password/"
      end)

      assert_no_email_sent()
    end

    test "returns 422 with the errors shape when email is missing", %{conn: conn} do
      for params <- [%{}, %{"email" => ""}, %{"email" => "   "}, %{"email" => 123}] do
        resp = request_reset(conn, params)

        assert json_response(resp, 422) == %{
                 "errors" => [%{"message" => "email is required"}]
               }
      end

      assert_no_email_sent()
    end

    test "trims and case-folds the email before matching", %{conn: conn} do
      user = user_fixture()

      resp = request_reset(conn, %{"email" => "  " <> String.upcase(user.email) <> " "})

      assert resp.status == 202
      assert_email_sent(to: user.email)
    end

    test "GET /api/v1/auth/reset-password is not routed", %{conn: conn} do
      conn = get(conn, "/api/v1/auth/reset-password")
      assert conn.status == 404
      assert_no_email_sent()
    end
  end
end
