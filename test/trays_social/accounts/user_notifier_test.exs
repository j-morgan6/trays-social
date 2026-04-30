defmodule TraysSocial.Accounts.UserNotifierTest do
  use TraysSocial.DataCase, async: true

  import TraysSocial.AccountsFixtures

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
end
