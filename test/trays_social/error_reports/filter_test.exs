defmodule TraysSocial.ErrorReports.FilterTest do
  use TraysSocial.DataCase, async: true

  alias ErrorTracker.Occurrence
  alias TraysSocial.ErrorReports.Filter

  @redacted "[REDACTED]"

  describe "sanitize/1" do
    test "redacts sensitive keys at any depth and case" do
      context = %{
        "request.params" => %{
          "user" => %{"email" => "cook@example.com", "Password" => "hunter2"},
          "current_password" => "old",
          "identity_token" => "apple-jwt",
          "jws" => "signed.transaction.value",
          "items" => [%{"refresh_token" => "rt"}, %{"name" => "kept"}],
          "caption" => "kept"
        },
        "live_view.event_params" => %{"user" => %{"password_confirmation" => "hunter2"}},
        recipient: "cook@example.com",
        subject: "Confirm your email"
      }

      sanitized = Filter.sanitize(context)
      params = sanitized["request.params"]

      assert params["user"] == %{"email" => @redacted, "Password" => @redacted}
      assert params["current_password"] == @redacted
      assert params["identity_token"] == @redacted
      assert params["jws"] == @redacted
      assert params["items"] == [%{"refresh_token" => @redacted}, %{"name" => "kept"}]
      assert params["caption"] == "kept"
      assert sanitized["live_view.event_params"]["user"]["password_confirmation"] == @redacted
      assert sanitized.recipient == @redacted
      assert sanitized.subject == "Confirm your email"
    end

    test "drops Authorization and Cookie headers" do
      context = %{
        "request.headers" => %{
          "Authorization" => "Bearer abc",
          "cookie" => "_trays_key=xyz",
          "set-cookie" => "a=b",
          "user-agent" => "TraysSocial/1.1.0"
        }
      }

      assert Filter.sanitize(context)["request.headers"] == %{"user-agent" => "TraysSocial/1.1.0"}
    end

    test "redacts tokens in the query string and token routes" do
      context = %{
        "request.query" => "token=abc123&page=2&user%5Bpassword%5D=x",
        "request.path" => "/users/log-in/SFMyNTY.secret"
      }

      sanitized = Filter.sanitize(context)

      assert sanitized["request.query"] ==
               "token=#{@redacted}&page=2&user%5Bpassword%5D=#{@redacted}"

      assert sanitized["request.path"] == "/users/log-in/#{@redacted}"
    end

    test "redacts a query key whose bracketed segment is sensitive" do
      context = %{"request.query" => "user%5Bemail%5D=cook%40example.com&user%5Bname%5D=Cook"}

      assert Filter.sanitize(context)["request.query"] ==
               "user%5Bemail%5D=#{@redacted}&user%5Bname%5D=Cook"
    end

    test "leaves ordinary paths, empty and non-map values alone" do
      context = %{
        "request.path" => "/api/v1/posts/42",
        "request.params" => nil,
        "request.query" => "",
        "request.headers" => "unfetched",
        "live_view.params" => ["a", 1, nil]
      }

      assert Filter.sanitize(context) == context
      assert Filter.sanitize(%{}) == %{}
      assert Filter.sanitize(nil) == nil
    end

    test "is idempotent" do
      context = %{"request.params" => %{"password" => "hunter2"}}
      once = Filter.sanitize(context)

      assert Filter.sanitize(once) == once
    end
  end

  describe "ErrorTracker integration" do
    test "an exception message carrying a password is stored redacted on the error and occurrence" do
      exception = %KeyError{key: :remember_me, term: %{"password" => "hunter2"}}

      ErrorTracker.report(exception, [])

      [occurrence] = Repo.all(Occurrence)
      [error] = Repo.all(ErrorTracker.Error)

      refute occurrence.reason =~ "hunter2"
      refute error.reason =~ "hunter2"
      assert occurrence.reason =~ ~s("password" => "[REDACTED]")
    end

    test "an error reported through ErrorTracker.report/3 with a password in params is stored redacted" do
      exception = %RuntimeError{message: "D120 filter integration"}

      ErrorTracker.report(exception, [], %{
        "request.params" => %{"user" => %{"email" => "cook@example.com", "password" => "hunter2"}},
        "request.headers" => %{"authorization" => "Bearer abc", "accept" => "application/json"}
      })

      [occurrence] = Repo.all(Occurrence)
      stored = Jason.encode!(occurrence.context)

      refute stored =~ "hunter2"
      refute stored =~ "cook@example.com"
      refute stored =~ "Bearer abc"
      assert occurrence.context["request.params"]["user"]["password"] == @redacted
      assert occurrence.context["request.headers"] == %{"accept" => "application/json"}
    end
  end
end
