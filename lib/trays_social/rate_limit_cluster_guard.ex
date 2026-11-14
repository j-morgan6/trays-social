defmodule TraysSocial.RateLimitClusterGuard do
  @moduledoc """
  W265: a tripwire for the one-machine rate-limit invariant.

  Every Hammer limit in this app uses `Hammer.Backend.ETS` (`config/config.exs`),
  so each BEAM node keeps its own buckets: on N machines each limit is N times
  its stated value. Production runs one machine on purpose; the decision and
  the alternatives are in the Rate limits section of `docs/infra/fly-inventory.md`.
  This process watches for nodes joining the cluster and logs a warning when
  one does, so a second machine never multiplies the limits silently. It logs
  only; it changes no limit.

  It subscribes to node events and then reads the current node list, so a node
  that joined before this process started (DNSCluster racing it) is still
  reported. Peers already connected at init produce one consolidated warning
  carrying their count, not one per peer. After that, each `:nodeup` logs once;
  a node that leaves and rejoins logs again.

  The warning carries only the connected-node count. Node names embed the
  machine's private IP (`rel/env.sh.eex`), so they are never logged, and only
  their hashes are kept in state so a crash report cannot print them.

  Hidden nodes (a release `remote` console connects hidden) are not visible to
  `Node.list/0` or node monitoring, so an operator console does not trigger it.

  On a node where node monitoring is unavailable the guard logs nothing and
  keeps running; it never takes the supervision tree down.
  """
  use GenServer

  require Logger

  @doc_path "docs/infra/fly-inventory.md"

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    nodes_fun = Keyword.get(opts, :nodes_fun, &Node.list/0)
    monitor_fun = Keyword.get(opts, :monitor_fun, &:net_kernel.monitor_nodes/1)

    # Subscribe first, then read the node list, so no join falls between them.
    monitoring = start_monitor(monitor_fun)
    state = %{nodes_fun: nodes_fun, warned: MapSet.new(), monitoring: monitoring}

    {:ok, warn_existing(state)}
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    key = :erlang.phash2(node)

    if MapSet.member?(state.warned, key) do
      # Already counted in the init warning; this is its queued nodeup.
      {:noreply, state}
    else
      warn(max(length(safe_nodes(state.nodes_fun)), 1))
      {:noreply, %{state | warned: MapSet.put(state.warned, key)}}
    end
  end

  def handle_info({:nodedown, node}, state) do
    {:noreply, %{state | warned: MapSet.delete(state.warned, :erlang.phash2(node))}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp start_monitor(monitor_fun) do
    monitor_fun.(true) == :ok
  rescue
    _ -> false
  catch
    _, _ -> false
  end

  defp warn_existing(state) do
    case safe_nodes(state.nodes_fun) do
      [] ->
        state

      nodes ->
        warn(length(nodes))
        %{state | warned: MapSet.new(nodes, &:erlang.phash2/1)}
    end
  end

  defp safe_nodes(nodes_fun) do
    case nodes_fun.() do
      nodes when is_list(nodes) -> nodes
      _ -> []
    end
  rescue
    _ -> []
  catch
    _, _ -> []
  end

  defp warn(count) do
    Logger.warning(
      "rate limits are per machine: connected_nodes=#{count}, so each Hammer limit " <>
        "now allows up to #{count + 1} times its stated value. " <>
        "See the Rate limits section of #{@doc_path}"
    )
  end
end
