defmodule TraysSocial.Feedback.NotifierTest do
  # Not async: these tests change :admin_emails, :disable_rate_limiting and
  # the Mailer adapter through global Application env, and the cap uses a
  # global Hammer bucket.
  use TraysSocial.DataCase, async: false

  import ExUnit.CaptureLog
  import Swoosh.TestAssertions
  import TraysSocial.AccountsFixtures
  import TraysSocial.MailerTestHelpers

  alias TraysSocial.Accounts
  alias TraysSocial.Feedback
  alias TraysSocial.Feedback.Notifier
  alias TraysSocial.Feedback.Submission

  @admins ["dev-one@example.test", "dev-two@example.test"]

  setup do
    original_admins = Application.fetch_env(:trays_social, :admin_emails)
    original_disable = Application.fetch_env(:trays_social, :disable_rate_limiting)
    Application.put_env(:trays_social, :admin_emails, @admins)

    on_exit(fn ->
      restore(:admin_emails, original_admins)
      restore(:disable_rate_limiting, original_disable)
      Enum.each(Notifier.cap_buckets(), &Hammer.delete_buckets/1)
    end)

    :ok
  end

  defp restore(key, {:ok, value}), do: Application.put_env(:trays_social, key, value)
  defp restore(key, :error), do: Application.delete_env(:trays_social, key)

  # A stored submission, built without Feedback.submit/2 so no notification
  # task runs alongside the direct call under test.
  defp submission(attrs \\ %{}) do
    user = Map.get_lazy(attrs, :user, &user_fixture/0)

    %Submission{user_id: user.id}
    |> Submission.submit_changeset(Map.delete(attrs, :user) |> Enum.into(%{body: "It broke."}))
    |> Repo.insert!()
  end

  describe "notify_new_submission/1" do
    test "notify_new_submission/1 emails each admin address with kind, platform, versions and the admin link" do
      long_body = String.duplicate("a", 450) <> String.duplicate("b", 150)

      sub =
        submission(%{
          kind: "bug",
          platform: "ios",
          subject: "Crash on save",
          body: long_body,
          app_version: "1.1.0",
          app_build: "372",
          os_version: "17.5",
          device_model: "iPhone15,3",
          screen: "RecipeEditor"
        })

      assert :ok = Notifier.notify_new_submission(sub)

      link = TraysSocialWeb.Endpoint.url() <> "/admin/feedback/#{sub.id}"

      for admin <- @admins do
        assert_received {:email, %Swoosh.Email{to: [{_, ^admin}]} = email}

        assert email.subject == "[Trays] New bug report: Crash on save"
        assert email.html_body == nil
        assert email.text_body =~ "Kind: bug"
        assert email.text_body =~ "Platform: ios"
        assert email.text_body =~ "App version: 1.1.0 (372)"
        assert email.text_body =~ "OS: 17.5"
        assert email.text_body =~ "Device: iPhone15,3"
        assert email.text_body =~ "Screen: RecipeEditor"
        assert email.text_body =~ link

        # A 500-character excerpt, not the whole 600-character body.
        assert email.text_body =~ String.slice(long_body, 0, 500) <> "..."
        refute email.text_body =~ String.duplicate("b", 51)
      end

      refute_received {:email, _}
    end

    test "notify_new_submission/1 strips line breaks from the subject line" do
      sub =
        submission(%{
          subject: "Crash\r\nBcc: attacker@example.test\n" <> String.duplicate("x", 150)
        })

      assert :ok = Notifier.notify_new_submission(sub)
      assert_received {:email, email}

      refute email.subject =~ "\r"
      refute email.subject =~ "\n"
      assert email.subject =~ "[Trays] New feedback: Crash Bcc: attacker@example.test"
      assert String.length(email.subject) <= String.length("[Trays] New feedback: ") + 80
    end

    test "uses the body for the subject line when there is no subject" do
      sub = submission(%{body: "Line one\nLine two"})

      assert :ok = Notifier.notify_new_submission(sub)
      assert_received {:email, email}
      assert email.subject == "[Trays] New feedback: Line one Line two"
      assert email.text_body =~ "App version: unknown"
      assert email.text_body =~ "Screen: unknown"
    end

    test "uses the body when the subject has no visible text" do
      sub = submission(%{subject: " \r\n\t ", body: "Real report text"})

      assert :ok = Notifier.notify_new_submission(sub)
      assert_received {:email, email}
      assert email.subject == "[Trays] New feedback: Real report text"
    end

    test "notify_new_submission/1 sends nothing when no admin address is configured" do
      sub = submission()

      Application.put_env(:trays_social, :admin_emails, [])
      assert :skipped = Notifier.notify_new_submission(sub)

      Application.delete_env(:trays_social, :admin_emails)
      assert :skipped = Notifier.notify_new_submission(sub)

      assert_no_email_sent()
    end

    test "sends at most 30 notifications per hour and logs the cap once" do
      Application.put_env(:trays_social, :disable_rate_limiting, false)
      Application.put_env(:trays_social, :admin_emails, ["dev-one@example.test"])
      Enum.each(Notifier.cap_buckets(), &Hammer.delete_buckets/1)
      sub = submission()

      log =
        capture_log(fn ->
          for _ <- 1..30, do: assert(:ok = Notifier.notify_new_submission(sub))
          assert :capped = Notifier.notify_new_submission(sub)
          assert :capped = Notifier.notify_new_submission(sub)
        end)

      sent = for _ <- 1..30, do: assert_received({:email, _})
      assert length(sent) == 30
      refute_received {:email, _}

      assert length(String.split(log, "feedback notification cap reached")) == 2
    end

    test "logs a failed email and reports it to ErrorTracker" do
      sub = submission(%{body: "secret-ish body text"})

      log =
        capture_log(fn ->
          with_failing_mailer(fn ->
            assert {:error, :simulated_mailer_failure} = Notifier.notify_new_submission(sub)
          end)
        end)

      assert log =~ "feedback notification failed: submission_id=#{sub.id}"
      refute log =~ "secret-ish body text"
      refute log =~ "dev-one@example.test"

      assert [%ErrorTracker.Error{reason: "email_delivery_failed"}] = Repo.all(ErrorTracker.Error)
    end

    test "still sends without crashing after the user deletes their account" do
      user = user_fixture()
      sub = submission(%{user: user})

      assert {:ok, _} = Accounts.delete_account(user)
      refute Repo.get(Submission, sub.id)

      assert :ok = Notifier.notify_new_submission(sub)
      assert_received {:email, _}
    end
  end

  describe "Feedback.submit/2" do
    test "sends the notification from a supervised task after storing the row" do
      user = user_fixture()

      assert {:ok, sub} = Feedback.submit(user, %{kind: "bug", body: "From submit/2"})
      await_mailer_tasks()

      link = TraysSocialWeb.Endpoint.url() <> "/admin/feedback/#{sub.id}"
      assert_email_sent(fn email -> assert email.text_body =~ link end)
    end
  end
end
