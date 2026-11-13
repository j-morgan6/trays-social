defmodule TraysSocial.FeedbackTest do
  # Not async: the notification-failure test swaps the Mailer adapter and the
  # :admin_emails list through global Application env.
  use TraysSocial.DataCase, async: false

  import ExUnit.CaptureLog
  import TraysSocial.AccountsFixtures
  import TraysSocial.MailerTestHelpers

  alias TraysSocial.Feedback
  alias TraysSocial.Feedback.Submission

  # By default no admin address is configured, so submissions in these tests
  # send nothing; the tests that need an email set their own list.
  setup do
    original = Application.fetch_env(:trays_social, :admin_emails)
    Application.put_env(:trays_social, :admin_emails, [])

    on_exit(fn ->
      case original do
        {:ok, value} -> Application.put_env(:trays_social, :admin_emails, value)
        :error -> Application.delete_env(:trays_social, :admin_emails)
      end
    end)

    :ok
  end

  # Every submission notifies from a supervised task; wait for it so no task
  # outlives the test.
  defp submit(user, attrs) do
    result = Feedback.submit(user, attrs)
    await_mailer_tasks()
    result
  end

  describe "submit/2" do
    test "submit/2 stores kind, platform, app_build, screen and user_agent with the user" do
      user = user_fixture()

      assert {:ok, %Submission{} = sub} =
               submit(user, %{
                 kind: "bug",
                 platform: "web",
                 subject: "Crash on save",
                 body: "Tapped Save and the app crashed.",
                 app_version: "1.1.0",
                 app_build: "372",
                 os_version: "17.5",
                 device_model: "iPhone15,3",
                 screen: "RecipeEditor",
                 user_agent: "Mozilla/5.0 (Macintosh)"
               })

      stored = Repo.get!(Submission, sub.id)
      assert stored.user_id == user.id
      assert stored.kind == "bug"
      assert stored.platform == "web"
      assert stored.app_build == "372"
      assert stored.screen == "RecipeEditor"
      assert stored.user_agent == "Mozilla/5.0 (Macintosh)"
      assert stored.body == "Tapped Save and the app crashed."
      assert stored.status == "new"
    end

    test "submit/2 ignores a user_id in attrs and uses the given user" do
      user = user_fixture()
      other = user_fixture()

      assert {:ok, atom_keys} = submit(user, %{user_id: other.id, body: "atom keys"})
      assert {:ok, string_keys} = submit(user, %{"user_id" => other.id, "body" => "string keys"})

      assert Repo.get!(Submission, atom_keys.id).user_id == user.id
      assert Repo.get!(Submission, string_keys.id).user_id == user.id
    end

    test "submit/2 rejects an unknown kind or platform" do
      user = user_fixture()

      assert {:error, changeset} = submit(user, %{body: "ok", kind: "crash"})
      assert "is invalid" in errors_on(changeset).kind

      assert {:error, changeset} = submit(user, %{body: "ok", platform: "android"})
      assert "is invalid" in errors_on(changeset).platform

      assert Repo.aggregate(Submission, :count) == 0
    end

    test "submit/2 rejects a body over 5,000 characters and a whitespace-only body" do
      user = user_fixture()

      assert {:error, changeset} = submit(user, %{body: String.duplicate("a", 5001)})
      assert "should be at most 5000 character(s)" in errors_on(changeset).body

      assert {:error, changeset} = submit(user, %{body: "   \n\t  "})
      assert errors_on(changeset).body == ["can't be blank"]

      assert Repo.aggregate(Submission, :count) == 0
    end

    test "rejects a missing body" do
      user = user_fixture()

      assert {:error, changeset} = submit(user, %{})
      assert errors_on(changeset).body == ["can't be blank"]
    end

    test "stores a body with newlines, tabs and control characters as typed, trimmed only at the ends" do
      user = user_fixture()

      inner =
        "Steps:\n1. Open a recipe\n\n\t2. Tap Save\r\nGot \u0007 then <script>alert(1)</script>"

      assert {:ok, sub} = submit(user, %{body: "  \n" <> inner <> "\n\t "})
      assert Repo.get!(Submission, sub.id).body == inner
    end

    test "accepts a body exactly at the 5000-char limit" do
      user = user_fixture()

      assert {:ok, %Submission{} = sub} = submit(user, %{body: String.duplicate("b", 5000)})
      assert String.length(sub.body) == 5000
    end

    test "rejects subject over 200 chars" do
      user = user_fixture()

      assert {:error, changeset} =
               submit(user, %{subject: String.duplicate("s", 201), body: "ok"})

      assert "should be at most 200 character(s)" in errors_on(changeset).subject
    end

    test "rejects app_build, screen and user_agent over their limits" do
      user = user_fixture()

      assert {:error, changeset} =
               submit(user, %{
                 body: "ok",
                 app_build: String.duplicate("1", 65),
                 screen: String.duplicate("s", 121),
                 user_agent: String.duplicate("u", 513)
               })

      errors = errors_on(changeset)
      assert "should be at most 64 character(s)" in errors.app_build
      assert "should be at most 120 character(s)" in errors.screen
      assert "should be at most 512 character(s)" in errors.user_agent
    end

    test "submit/2 defaults kind to feedback when it is absent" do
      user = user_fixture()

      # Absent keys, as sent by shipped iOS builds.
      assert {:ok, absent} = submit(user, %{body: "no kind"})
      # Explicit nils, as a caller passing params["kind"] straight through would send.
      assert {:ok, nils} = submit(user, %{"body" => "nil kind", "kind" => nil, "platform" => nil})
      # Empty strings, which cast turns into nil.
      assert {:ok, empty} =
               submit(user, %{"body" => "empty kind", "kind" => "", "platform" => ""})

      for sub <- [absent, nils, empty] do
        stored = Repo.get!(Submission, sub.id)
        assert stored.kind == "feedback"
        assert stored.platform == "ios"
      end
    end

    test "submit/2 keeps the row when the notification email fails" do
      user = user_fixture()
      Application.put_env(:trays_social, :admin_emails, ["dev-one@example.test"])

      log =
        capture_log(fn ->
          with_failing_mailer(fn ->
            assert {:ok, sub} = Feedback.submit(user, %{kind: "bug", body: "It broke."})
            # Wait inside the swap so the task delivers through the failing adapter.
            await_mailer_tasks()
            send(self(), {:submission, sub})
          end)
        end)

      assert_received {:submission, sub}
      assert Repo.get!(Submission, sub.id).body == "It broke."

      assert log =~ "feedback notification failed"
      assert log =~ "submission_id=#{sub.id}"
      assert log =~ "simulated_mailer_failure"
      refute log =~ "It broke."
      refute log =~ "dev-one@example.test"

      assert [%ErrorTracker.Error{kind: "Elixir.RuntimeError", reason: "email_delivery_failed"}] =
               Repo.all(ErrorTracker.Error)
    end

    test "existing rows without kind or platform read as feedback and ios after the migration" do
      user = user_fixture()

      # Insert with only the columns the table had before W260, so the
      # migration's column defaults supply kind and platform.
      {1, [%{id: id}]} =
        Repo.insert_all(
          "feedback_submissions",
          [
            %{
              user_id: user.id,
              body: "Stored before W260",
              app_version: "1.0.0",
              status: "new",
              inserted_at: DateTime.utc_now(:second)
            }
          ],
          returning: [:id]
        )

      stored = Feedback.get_submission!(id)
      assert stored.kind == "feedback"
      assert stored.platform == "ios"
      assert stored.app_build == nil
      assert stored.screen == nil
      assert stored.user_agent == nil
    end
  end

  describe "list_recent/1" do
    test "orders newest first" do
      user = user_fixture()
      {:ok, oldest} = submit(user, %{body: "first"})
      # inserted_at is second-precision; sleep 1.1s so the second
      # record gets a strictly later timestamp.
      Process.sleep(1100)
      {:ok, newest} = submit(user, %{body: "second"})

      ids = Enum.map(Feedback.list_recent(), & &1.id)
      assert Enum.find_index(ids, &(&1 == newest.id)) < Enum.find_index(ids, &(&1 == oldest.id))
    end

    test "filters by status" do
      user = user_fixture()
      {:ok, sub} = submit(user, %{body: "needs triage"})
      submit(user, %{body: "untouched"})

      {:ok, _} = Feedback.mark_triaged(sub)

      assert length(Feedback.list_recent(status: "triaged")) == 1
      assert length(Feedback.list_recent(status: "new")) == 1
    end

    test "filters by kind and platform" do
      user = user_fixture()
      {:ok, ios_bug} = submit(user, %{body: "ios bug", kind: "bug"})
      {:ok, web_bug} = submit(user, %{body: "web bug", kind: "bug", platform: "web"})
      {:ok, web_feedback} = submit(user, %{body: "web idea", platform: "web"})

      ids = fn opts -> opts |> Feedback.list_recent() |> Enum.map(& &1.id) |> Enum.sort() end

      assert ids.(kind: "bug") == Enum.sort([ios_bug.id, web_bug.id])
      assert ids.(platform: "web") == Enum.sort([web_bug.id, web_feedback.id])
      assert ids.(kind: "bug", platform: "ios") == [ios_bug.id]
      assert length(Feedback.list_recent(kind: "", platform: nil)) == 3
    end

    test "respects limit" do
      user = user_fixture()
      for _ <- 1..5, do: submit(user, %{body: "f"})

      assert length(Feedback.list_recent(limit: 2)) == 2
    end
  end

  describe "mark_triaged/1 and mark_resolved/1" do
    test "transitions status" do
      user = user_fixture()
      {:ok, sub} = submit(user, %{body: "needs triage"})

      assert {:ok, triaged} = Feedback.mark_triaged(sub)
      assert triaged.status == "triaged"

      assert {:ok, resolved} = Feedback.mark_resolved(triaged)
      assert resolved.status == "resolved"
    end
  end

  describe "get_submission!/1" do
    test "preloads user" do
      user = user_fixture()
      {:ok, sub} = submit(user, %{body: "preloaded"})

      assert Feedback.get_submission!(sub.id).user.id == user.id
    end
  end
end
