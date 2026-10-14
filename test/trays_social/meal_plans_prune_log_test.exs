defmodule TraysSocial.MealPlansPruneLogTest do
  # async: false — asserting an :info line means lowering the GLOBAL Logger
  # level (test.exs sets :warning). Logger.put_process_level/2 is not enough:
  # the primary :logger level still drops the event. Sync modules run after
  # every async module, so the global change cannot leak into the async suite.
  use TraysSocial.DataCase, async: false

  import ExUnit.CaptureLog
  import TraysSocial.AccountsFixtures

  alias TraysSocial.MealPlans

  require Logger

  @monday ~D[2026-03-02]

  setup do
    original_level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: original_level) end)
  end

  test "prune_grocery_checks/1 logs the number of rows deleted" do
    user = user_fixture()
    old_week = Date.add(@monday, -21)
    :ok = MealPlans.set_check(user.id, old_week, "1:2", true)

    log =
      capture_log(fn ->
        assert {:ok, 1} =
                 MealPlans.prune_grocery_checks(retention_weeks: 2, today: Date.add(@monday, 2))
      end)

    assert log =~
             "grocery_checks prune: deleted=1 cutoff=#{Date.add(@monday, -14)} retention_weeks=2"
  end
end
