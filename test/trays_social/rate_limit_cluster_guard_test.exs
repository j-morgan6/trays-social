defmodule TraysSocial.RateLimitClusterGuardTest do
  # async: true is safe: every instance here is unnamed and gets its node list
  # and monitor function injected, so nothing touches real distribution or the
  # application's own named guard (except the read-only supervisor test).
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias TraysSocial.RateLimitClusterGuard

  @phrase "rate limits are per machine"
  # Node names on Fly embed the private IP (rel/env.sh.eex), so the fakes do too.
  @node_a :"trays-social-01abc@fdaa:0:1:a7b::2"
  @node_b :"trays-social-02def@fdaa:0:1:a7b::3"

  defp start_guard(initial_nodes, opts \\ []) do
    agent = start_supervised!({Agent, fn -> initial_nodes end}, id: :nodes)

    guard_opts =
      Keyword.merge(
        [name: nil, nodes_fun: fn -> Agent.get(agent, & &1) end, monitor_fun: fn _ -> :ok end],
        opts
      )

    pid = start_supervised!({RateLimitClusterGuard, guard_opts})
    {pid, agent}
  end

  # :sys.get_state/1 is a call handled after every message already sent, so the
  # guard has processed (and logged) them by the time it returns.
  defp deliver(pid, msg) do
    send(pid, msg)
    :sys.get_state(pid)
  end

  defp warnings(log), do: length(String.split(log, @phrase)) - 1

  test "logs a per-machine warning when a node joins" do
    log =
      capture_log(fn ->
        {pid, agent} = start_guard([])
        Agent.update(agent, fn _ -> [@node_a] end)
        deliver(pid, {:nodeup, @node_a})
      end)

    assert warnings(log) == 1
    assert log =~ "connected_nodes=1"
    assert log =~ "docs/infra/fly-inventory.md"
  end

  test "warns at init when peers are already connected" do
    # init runs inside start_supervised!, so its warning is logged on return.
    {pid, init_log} = with_log(fn -> start_guard([@node_a, @node_b]) |> elem(0) end)

    assert warnings(init_log) == 1
    assert init_log =~ "connected_nodes=2"

    # The queued nodeup for a peer already counted at init does not log again.
    nodeup_log = capture_log(fn -> deliver(pid, {:nodeup, @node_a}) end)

    assert warnings(nodeup_log) == 0
  end

  test "keeps running when node monitoring is unavailable" do
    failing_monitors = [
      fn _ -> raise "not distributed" end,
      fn _ -> {:error, :nodistribution} end,
      fn _ -> exit(:noproc) end
    ]

    for monitor_fun <- failing_monitors do
      log =
        capture_log(fn ->
          {pid, _agent} = start_guard([], monitor_fun: monitor_fun)
          assert Process.alive?(pid)
          assert :sys.get_state(pid).monitoring == false
          stop_supervised!(RateLimitClusterGuard)
          stop_supervised!(:nodes)
        end)

      assert warnings(log) == 0
    end
  end

  test "starts and logs nothing with no peers" do
    log =
      capture_log(fn ->
        {pid, _agent} = start_guard([])
        assert Process.alive?(pid)
        assert :sys.get_state(pid).monitoring == true
      end)

    assert warnings(log) == 0
  end

  test "does not log on nodedown" do
    {pid, agent} = start_guard([])

    join_log =
      capture_log(fn ->
        Agent.update(agent, fn _ -> [@node_a] end)
        deliver(pid, {:nodeup, @node_a})
      end)

    assert warnings(join_log) == 1

    down_log =
      capture_log(fn ->
        Agent.update(agent, fn _ -> [] end)
        deliver(pid, {:nodedown, @node_a})
      end)

    assert warnings(down_log) == 0

    # A rejoin is a new nodeup and logs again.
    rejoin_log =
      capture_log(fn ->
        Agent.update(agent, fn _ -> [@node_a] end)
        deliver(pid, {:nodeup, @node_a})
      end)

    assert warnings(rejoin_log) == 1
  end

  test "logs the connected-node count and no node name" do
    {state, log} =
      with_log(fn ->
        {pid, agent} = start_guard([@node_a])
        Agent.update(agent, fn _ -> [@node_a, @node_b] end)
        deliver(pid, {:nodeup, @node_b})
      end)

    assert log =~ "connected_nodes=1"
    assert log =~ "connected_nodes=2"
    refute log =~ "trays-social-01abc"
    refute log =~ "trays-social-02def"
    refute log =~ "fdaa"

    # Hashes only: no node atom is kept in state, so a crash report cannot
    # print one either.
    assert MapSet.size(state.warned) == 2
    refute Enum.any?(state.warned, &is_atom/1)
  end

  test "is running under the application supervisor" do
    pid = Process.whereis(RateLimitClusterGuard)

    assert is_pid(pid)
    assert Process.alive?(pid)

    children = Supervisor.which_children(TraysSocial.Supervisor)

    assert Enum.any?(children, fn
             {RateLimitClusterGuard, ^pid, :worker, _} -> true
             _ -> false
           end)
  end
end
