defmodule TraysSocial.FeedbackTest do
  use TraysSocial.DataCase, async: true

  import TraysSocial.AccountsFixtures

  alias TraysSocial.Feedback
  alias TraysSocial.Feedback.Submission

  describe "submit/1" do
    test "creates a submission with body + user_id" do
      user = user_fixture()

      assert {:ok, %Submission{} = sub} =
               Feedback.submit(%{
                 user_id: user.id,
                 subject: "Crash on save",
                 body: "Tapped Save and the app crashed.",
                 app_version: "1.0.0",
                 os_version: "17.5",
                 device_model: "iPhone15,3"
               })

      assert sub.user_id == user.id
      assert sub.body == "Tapped Save and the app crashed."
      assert sub.status == "new"
    end

    test "trims whitespace-only body and rejects as empty" do
      user = user_fixture()

      assert {:error, changeset} =
               Feedback.submit(%{user_id: user.id, body: "   \n\t  "})

      assert errors_on(changeset).body == ["can't be blank"]
    end

    test "rejects missing body" do
      user = user_fixture()

      assert {:error, changeset} = Feedback.submit(%{user_id: user.id})
      assert errors_on(changeset).body == ["can't be blank"]
    end

    test "rejects body over 5000 chars" do
      user = user_fixture()
      over = String.duplicate("a", 5001)

      assert {:error, changeset} = Feedback.submit(%{user_id: user.id, body: over})
      assert "should be at most 5000 character(s)" in errors_on(changeset).body
    end

    test "rejects subject over 200 chars" do
      user = user_fixture()
      over = String.duplicate("s", 201)

      assert {:error, changeset} =
               Feedback.submit(%{user_id: user.id, subject: over, body: "ok"})

      assert "should be at most 200 character(s)" in errors_on(changeset).subject
    end

    test "requires user_id" do
      assert {:error, changeset} = Feedback.submit(%{body: "orphan submission"})
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "accepts a body exactly at the 5000-char limit" do
      user = user_fixture()
      at = String.duplicate("b", 5000)

      assert {:ok, %Submission{} = sub} =
               Feedback.submit(%{user_id: user.id, body: at})

      assert String.length(sub.body) == 5000
    end
  end

  describe "list_recent/1" do
    test "orders newest first" do
      user = user_fixture()
      {:ok, oldest} = Feedback.submit(%{user_id: user.id, body: "first"})
      # inserted_at is second-precision; sleep 1.1s so the second
      # record gets a strictly later timestamp.
      Process.sleep(1100)
      {:ok, newest} = Feedback.submit(%{user_id: user.id, body: "second"})

      records = Feedback.list_recent()
      ids = Enum.map(records, & &1.id)
      newest_pos = Enum.find_index(ids, &(&1 == newest.id))
      oldest_pos = Enum.find_index(ids, &(&1 == oldest.id))

      assert newest_pos < oldest_pos
    end

    test "filters by status" do
      user = user_fixture()
      {:ok, sub} = Feedback.submit(%{user_id: user.id, body: "needs triage"})
      Feedback.submit(%{user_id: user.id, body: "untouched"})

      {:ok, _} = Feedback.mark_triaged(sub)

      assert length(Feedback.list_recent(status: "triaged")) == 1
      assert length(Feedback.list_recent(status: "new")) == 1
    end

    test "respects limit" do
      user = user_fixture()
      for _ <- 1..5, do: Feedback.submit(%{user_id: user.id, body: "f"})

      assert length(Feedback.list_recent(limit: 2)) == 2
    end
  end

  describe "mark_triaged/1 and mark_resolved/1" do
    test "transitions status" do
      user = user_fixture()
      {:ok, sub} = Feedback.submit(%{user_id: user.id, body: "needs triage"})

      assert {:ok, triaged} = Feedback.mark_triaged(sub)
      assert triaged.status == "triaged"

      assert {:ok, resolved} = Feedback.mark_resolved(triaged)
      assert resolved.status == "resolved"
    end
  end

  describe "get_submission!/1" do
    test "preloads user" do
      user = user_fixture()
      {:ok, sub} = Feedback.submit(%{user_id: user.id, body: "preloaded"})

      fetched = Feedback.get_submission!(sub.id)
      assert fetched.user.id == user.id
    end
  end
end
