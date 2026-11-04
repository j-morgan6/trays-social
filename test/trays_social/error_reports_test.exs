defmodule TraysSocial.ErrorReportsTest do
  use TraysSocial.DataCase, async: true

  import Ecto.Query

  alias ErrorTracker.Error
  alias ErrorTracker.Occurrence
  alias TraysSocial.ErrorReports
  alias TraysSocial.ErrorReports.Pruner

  @now ~U[2026-11-04 12:00:00.000000Z]

  describe "prune/1" do
    test "prune deletes occurrences older than the window and keeps newer ones" do
      old = report(RuntimeError, days_ago(31))
      edge = report(ArgumentError, 30 |> days_ago() |> DateTime.add(60, :second))

      assert {:ok, %{occurrences: 1, errors: 1}} =
               ErrorReports.prune(retention_days: 30, now: @now)

      refute Repo.get(Occurrence, old.id)
      assert Repo.get(Occurrence, edge.id)
      assert Repo.aggregate(Error, :count) == 1
    end

    test "prune removes errors left with no occurrences" do
      _gone = report(RuntimeError, days_ago(40))
      kept_old = report(KeyError, days_ago(40))
      _kept_new = report(KeyError, days_ago(1))

      assert {:ok, %{occurrences: 2, errors: 1}} =
               ErrorReports.prune(retention_days: 30, now: @now, batch_size: 1)

      # The KeyError error keeps its recent occurrence, so it survives.
      assert [%Error{kind: "Elixir.KeyError"}] = Repo.all(Error)
      refute Repo.get(Occurrence, kept_old.id)

      # Idempotent: a second (or concurrent) run deletes nothing.
      assert {:ok, %{occurrences: 0, errors: 0}} =
               ErrorReports.prune(retention_days: 30, now: @now)
    end

    test "never deletes an error whose last occurrence is inside the window" do
      occurrence = report(RuntimeError, days_ago(31))
      from(o in Occurrence, where: o.id == ^occurrence.id) |> Repo.delete_all()
      Repo.update_all(Error, set: [last_occurrence_at: days_ago(1)])

      assert {:ok, %{occurrences: 0, errors: 0}} =
               ErrorReports.prune(retention_days: 30, now: @now)

      assert Repo.aggregate(Error, :count) == 1
    end

    test "works on empty tables and rejects a bad retention" do
      assert {:ok, %{occurrences: 0, errors: 0}} = ErrorReports.prune(now: @now)

      assert_raise ArgumentError, ~r/positive integer/, fn ->
        ErrorReports.prune(retention_days: 0)
      end
    end
  end

  describe "reason redaction trigger" do
    test "redacts sensitive pairs, bearer credentials and emails before the row is written" do
      occurrence = report(RuntimeError, days_ago(1))

      message =
        ~s(key "remember_me" not found in: %{"user" => %{"email" => "cook@example.com", ) <>
          ~s("password" => "hunter2"}, "jws" => "a.b.c", :api_key => "k1"}, password: "kw", ) <>
          ~s(header Bearer abc.def-123 sent by other@example.org, caption: "kept")

      from(o in Occurrence, where: o.id == ^occurrence.id)
      |> Repo.update_all(set: [reason: message])

      stored = Repo.get!(Occurrence, occurrence.id).reason

      for secret <- ["hunter2", "a.b.c", ~s("kw"), "k1", "abc.def-123", "@example"] do
        refute stored =~ secret
      end

      assert stored =~ ~s("password" => "[REDACTED]")
      assert stored =~ ~s(password: "[REDACTED]")
      assert stored =~ "Bearer [REDACTED]"
      assert stored =~ ~s(caption: "kept")
      assert stored =~ ~s(key "remember_me" not found)
    end

    test "leaves an ordinary message alone and redacts the error row's reason too" do
      occurrence = report(RuntimeError, days_ago(1))

      from(e in Error, where: e.id == ^occurrence.error_id)
      |> Repo.update_all(set: [reason: ~s(no match: %{"token" => "t1"})])

      from(o in Occurrence, where: o.id == ^occurrence.id)
      |> Repo.update_all(set: [reason: "no match of right hand side value: :error"])

      assert Repo.get!(Error, occurrence.error_id).reason ==
               ~s(no match: %{"token" => "[REDACTED]"})

      assert Repo.get!(Occurrence, occurrence.id).reason ==
               "no match of right hand side value: :error"
    end
  end

  describe "scrub/1" do
    test "redacts secrets in reports stored before D120, and only those" do
      dirty = report(RuntimeError, days_ago(1))
      clean = report(ArgumentError, days_ago(1))

      # Seed pre-D120 plaintext: skip the redaction trigger for these writes.
      without_triggers(fn ->
        from(o in Occurrence, where: o.id == ^dirty.id)
        |> Repo.update_all(
          set: [
            context: %{"request.params" => %{"password" => "hunter2"}},
            reason: ~s(no match: %{"password" => "hunter2"})
          ]
        )

        from(e in Error, where: e.id == ^dirty.error_id)
        |> Repo.update_all(set: [reason: ~s(no match: %{"password" => "hunter2"})])
      end)

      assert Repo.get!(Error, dirty.error_id).reason =~ "hunter2"

      assert {:ok, %{scanned: 2, scrubbed: 1, reasons_rechecked: 4}} =
               ErrorReports.scrub(batch_size: 1)

      scrubbed = Repo.get!(Occurrence, dirty.id)
      assert scrubbed.context == %{"request.params" => %{"password" => "[REDACTED]"}}
      refute scrubbed.reason =~ "hunter2"
      refute Repo.get!(Error, dirty.error_id).reason =~ "hunter2"
      assert Repo.get!(Occurrence, clean.id).context == clean.context

      assert {:ok, %{scanned: 2, scrubbed: 0}} = ErrorReports.scrub()
    end
  end

  describe "Pruner" do
    test "run_now prunes with the configured retention" do
      old = report(RuntimeError, DateTime.add(DateTime.utc_now(), -40, :day))
      pid = start_supervised!({Pruner, name: nil, initial_delay: :timer.hours(1)})
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

      assert {:ok, %{occurrences: 1}} = Pruner.run_now(pid)
      refute Repo.get(Occurrence, old.id)
    end
  end

  defp days_ago(days), do: DateTime.add(@now, -days, :day)

  # session_replication_role = replica skips ordinary triggers for this
  # (sandboxed) transaction; SET LOCAL ends with it.
  defp without_triggers(fun) do
    Repo.query!("SET LOCAL session_replication_role = replica")
    fun.()
    Repo.query!("SET LOCAL session_replication_role = DEFAULT")
  end

  # Reports a real error through ErrorTracker, then backdates it. Errors are
  # fingerprinted by exception module and source, so each module is its own
  # error and a repeated module adds an occurrence to the same error.
  defp report(exception_module, at) do
    occurrence = exception_module.exception(message: "D120 test") |> ErrorTracker.report([])

    from(o in Occurrence, where: o.id == ^occurrence.id)
    |> Repo.update_all(set: [inserted_at: at])

    latest =
      from(o in Occurrence,
        where: o.error_id == ^occurrence.error_id,
        select: max(o.inserted_at)
      )
      |> Repo.one()

    from(e in Error, where: e.id == ^occurrence.error_id)
    |> Repo.update_all(set: [last_occurrence_at: latest])

    Repo.get!(Occurrence, occurrence.id)
  end
end
