defmodule TraysSocial.Accounts.UserNotifierTest do
  # Not async — these tests swap the Mailer adapter via Application.put_env to
  # exercise the error branch in deliver/4. Concurrent tests would race on the
  # global config. Switch back to async: true if you split out the failing-
  # adapter tests into their own module.
  use TraysSocial.DataCase, async: false

  import ExUnit.CaptureLog
  import TraysSocial.AccountsFixtures
  import TraysSocial.MailerTestHelpers

  alias TraysSocial.Accounts.UserNotifier

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
            assert {:error, :simulated_mailer_failure} =
                     UserNotifier.deliver_login_instructions(user, url)
          end)

        assert log =~ "email delivery failed"
        assert log =~ user.email
        assert log =~ "simulated_mailer_failure"

        # Same credential-safety guarantee on the error path.
        refute log =~ url
        refute log =~ "another-secret-token"
      end)
    end
  end

  describe "deliver_reset_password_instructions/2" do
    test "deliver_reset_password_instructions/2 sends the reset email with the link on its own line" do
      user = user_fixture()
      url = "https://trays.app/users/reset-password/reset-abc123"

      assert {:ok, email} = UserNotifier.deliver_reset_password_instructions(user, url)

      assert email.subject == "Reset your Trays password"
      assert email.to == [{"", user.email}]
      assert_email_html_contains_cta(email, url)
      assert_email_html_uses_brand_color(email)
      assert_email_text_contains_raw_url(email, url)
      assert email.text_body =~ "one hour"
      assert email.html_body =~ "one hour"
      assert email.html_body =~ "Set new password"
    end

    test "deliver_reset_password_instructions/2 returns an error tuple when the mailer fails" do
      user = user_fixture()
      url = "https://trays.app/users/reset-password/reset-secret-token"

      with_failing_mailer(fn ->
        log =
          capture_log(fn ->
            assert {:error, :simulated_mailer_failure} =
                     UserNotifier.deliver_reset_password_instructions(user, url)
          end)

        assert log =~ "email delivery failed"
        assert log =~ "Reset your Trays password"
        refute log =~ url
        refute log =~ "reset-secret-token"
      end)
    end
  end

  # D123: the notice must be useless to anyone but the address owner.
  describe "deliver_existing_account_notice/1" do
    test "deliver_existing_account_notice/1 contains no token or credential link" do
      user = user_fixture()
      base = TraysSocialWeb.Endpoint.url()
      tokens_before = user_token_count(user)

      assert {:ok, email} = UserNotifier.deliver_existing_account_notice(user)

      assert email.to == [{"", user.email}]
      assert email.subject == "Someone tried to create a Trays account with your email"
      assert_email_html_contains_cta(email, base <> "/users/log-in")
      assert_email_html_uses_brand_color(email)
      assert_email_text_contains_raw_url(email, base <> "/users/log-in")
      assert_email_text_contains_raw_url(email, base <> "/users/reset-password")
      assert email.html_body =~ ~s(href="#{base}/users/reset-password")

      # Every link in either body is exactly one of the two public pages:
      # no token path segment, no query string, nothing that acts by itself.
      links =
        Regex.scan(~r{https?://[^\s"<>]+}, email.text_body <> email.html_body)
        |> List.flatten()
        |> Enum.uniq()

      assert Enum.sort(links) ==
               Enum.sort([base <> "/users/log-in", base <> "/users/reset-password"])

      # And sending it builds no token for the account.
      assert user_token_count(user) == tokens_before
    end

    test "deliver_existing_account_notice/1 returns an error tuple when the mailer fails" do
      user = user_fixture()

      with_failing_mailer(fn ->
        log =
          capture_log(fn ->
            assert {:error, :simulated_mailer_failure} =
                     UserNotifier.deliver_existing_account_notice(user)
          end)

        assert log =~ "email delivery failed"
        refute log =~ "nothing was created"
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
      refute String.contains?(
               email.html_body,
               ~s(href="https://trays.app/users/confirm/token?foo=bar&baz=qux"x")
             ),
             "raw unescaped URL should not appear inside an href"

      assert String.contains?(email.html_body, "&amp;baz=qux")
      assert String.contains?(email.text_body, url)
    end
  end

  # ---------- helpers ----------

  defp user_token_count(user) do
    Repo.aggregate(
      from(t in TraysSocial.Accounts.UserToken, where: t.user_id == ^user.id),
      :count
    )
  end

  defp assert_email_html_contains_cta(email, url) do
    assert is_binary(email.html_body),
           "expected html_body to be set, got: #{inspect(email.html_body)}"

    assert email.html_body =~
             ~r/<a [^>]*href="[^"]*#{Regex.escape(escape_url_for_html(url))}[^"]*"/,
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
end
