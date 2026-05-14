defmodule TraysSocial.Accounts.UserNotifierTest do
  # Not async — these tests swap the Mailer adapter via Application.put_env to
  # exercise the error branch in deliver/4. Concurrent tests would race on the
  # global config. Switch back to async: true if you split out the failing-
  # adapter tests into their own module.
  use TraysSocial.DataCase, async: false

  import ExUnit.CaptureLog
  import TraysSocial.AccountsFixtures

  alias TraysSocial.Accounts.UserNotifier

  # D63: a Swoosh adapter that always returns an error. Used to verify the
  # error branch in UserNotifier.deliver/4 logs + reports without changing
  # the production code path.
  defmodule FailingAdapter do
    @behaviour Swoosh.Adapter

    @impl true
    def deliver(_email, _config), do: {:error, :simulated_resend_suppression}

    @impl true
    def validate_config(_config), do: :ok
  end

  @primary_color "#1B5E20"

  describe "deliver_confirmation_instructions/2" do
    test "sends email with branded subject, html_body containing CTA link, and text_body with the URL" do
      user = unconfirmed_user_fixture()
      url = "https://trays.app/users/confirm/abc123"

      assert {:ok, email} = UserNotifier.deliver_confirmation_instructions(user, url)

      assert email.subject == "Confirm your Trays account"
      assert_email_html_contains_cta(email, url)
      assert_email_html_uses_brand_color(email)
      assert_email_text_contains_raw_url(email, url)
    end
  end

  describe "deliver_update_email_instructions/2" do
    test "sends email with branded subject, html_body containing CTA link, and text_body with the URL" do
      user = user_fixture()
      url = "https://trays.app/users/settings/confirm-email/xyz789"

      assert {:ok, email} = UserNotifier.deliver_update_email_instructions(user, url)

      assert email.subject == "Update your Trays email"
      assert_email_html_contains_cta(email, url)
      assert_email_html_uses_brand_color(email)
      assert_email_text_contains_raw_url(email, url)
    end
  end

  describe "deliver_login_instructions/2" do
    test "for an unconfirmed user, dispatches to confirmation email and uses confirmation subject" do
      user = unconfirmed_user_fixture()
      url = "https://trays.app/users/log-in/t/qwerty"

      assert {:ok, email} = UserNotifier.deliver_login_instructions(user, url)

      assert email.subject == "Confirm your Trays account"
      assert_email_html_contains_cta(email, url)
      assert_email_text_contains_raw_url(email, url)
    end

    test "for a confirmed user, sends magic-link email with login subject and CTA" do
      user = user_fixture()
      url = "https://trays.app/users/log-in/t/abcdef"

      assert {:ok, email} = UserNotifier.deliver_login_instructions(user, url)

      assert email.subject == "Log in to Trays"
      assert_email_html_contains_cta(email, url)
      assert_email_html_uses_brand_color(email)
      assert_email_text_contains_raw_url(email, url)
    end
  end

  describe "delivery observability (D63)" do
    test "logs an info line on successful send (credentials never leak into logs)" do
      user = user_fixture()
      url = "https://trays.app/users/log-in/t/secret-token-must-not-appear-in-log"

      # Test env has Logger at :warning. Lower it just for this test so the
      # info-level success line is captured.
      original_level = Logger.level()
      Logger.configure(level: :info)
      on_exit_log = fn -> Logger.configure(level: original_level) end

      log =
        try do
          capture_log(fn ->
            assert {:ok, _email} = UserNotifier.deliver_login_instructions(user, url)
          end)
        after
          on_exit_log.()
        end

      # Sanity: the success info line fired and includes recipient + subject.
      assert log =~ "email sent"
      assert log =~ user.email
      assert log =~ "Log in to Trays"

      # Credential safety: the magic-link token and full URL MUST NOT appear
      # anywhere in the log output. Logs ship to Fly stdout (longer retention
      # than the DB) so leaking a credential there is worse than leaking it
      # in the audit trail.
      refute log =~ url
      refute log =~ "secret-token-must-not-appear-in-log"
    end

    test "logs an error line AND returns {:error, reason} when Mailer fails" do
      user = user_fixture()
      url = "https://trays.app/users/log-in/t/another-secret-token"

      with_failing_mailer(fn ->
        log =
          capture_log(fn ->
            assert {:error, :simulated_resend_suppression} =
                     UserNotifier.deliver_login_instructions(user, url)
          end)

        assert log =~ "email delivery failed"
        assert log =~ user.email
        assert log =~ "simulated_resend_suppression"

        # Same credential-safety guarantee on the error path.
        refute log =~ url
        refute log =~ "another-secret-token"
      end)
    end
  end

  describe "html escaping" do
    test "URLs containing & and quotes are encoded in href but unchanged in text_body" do
      user = unconfirmed_user_fixture()
      url = ~s(https://trays.app/users/confirm/token?foo=bar&baz=qux"x)

      assert {:ok, email} = UserNotifier.deliver_confirmation_instructions(user, url)

      # In the rendered HTML, the raw URL string must be encoded inside attributes
      # (& -> &amp;, " -> &quot;). The text_body must preserve the original URL
      # for extract_user_token/1 splitting in support fixtures.
      refute String.contains?(email.html_body, ~s(href="https://trays.app/users/confirm/token?foo=bar&baz=qux"x")),
             "raw unescaped URL should not appear inside an href"

      assert String.contains?(email.html_body, "&amp;baz=qux")
      assert String.contains?(email.text_body, url)
    end
  end

  # ---------- helpers ----------

  defp assert_email_html_contains_cta(email, url) do
    assert is_binary(email.html_body), "expected html_body to be set, got: #{inspect(email.html_body)}"

    assert email.html_body =~ ~r/<a [^>]*href="[^"]*#{Regex.escape(escape_url_for_html(url))}[^"]*"/,
           "expected html_body to contain an <a href> pointing at #{url}; got:\n#{email.html_body}"
  end

  defp assert_email_html_uses_brand_color(email) do
    assert String.contains?(email.html_body, @primary_color),
           "expected html_body to contain brand color #{@primary_color}"
  end

  defp assert_email_text_contains_raw_url(email, url) do
    assert is_binary(email.text_body), "expected text_body to be set"

    assert String.contains?(email.text_body, url),
           "expected text_body to contain the raw URL #{url} (required for extract_user_token/1)"
  end

  # The HTML body escapes &, ", ', etc. inside attribute values. To match a URL
  # that may contain these characters when it lives inside href="...", we
  # apply the same minimal encoding before regex-escaping.
  defp escape_url_for_html(url) do
    url
    |> String.replace("&", "&amp;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp with_failing_mailer(fun) do
    original = Application.get_env(:trays_social, TraysSocial.Mailer)

    Application.put_env(:trays_social, TraysSocial.Mailer, adapter: FailingAdapter)

    try do
      fun.()
    after
      if original == nil do
        Application.delete_env(:trays_social, TraysSocial.Mailer)
      else
        Application.put_env(:trays_social, TraysSocial.Mailer, original)
      end
    end
  end
end
