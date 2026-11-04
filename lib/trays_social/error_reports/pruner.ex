defmodule TraysSocial.ErrorReports.Pruner do
  @moduledoc """
  D120: runs `TraysSocial.ErrorReports.prune/1` on a timer. There is no Oban in
  this app, so this small supervised process is the scheduler.

  The first run waits `:initial_delay` so a boot never starts with a prune,
  then it repeats every `:interval`. A failed prune is logged (message only)
  and retried at the next tick; it never crashes the process. Every machine
  runs its own copy, which is safe because the prune's deletes are idempotent.

  Started from `TraysSocial.Application` unless
  `config :trays_social, :error_reports, prune_enabled: false` (test).
  """
  use GenServer

  alias TraysSocial.ErrorReports

  require Logger

  @default_interval :timer.hours(24)
  @default_initial_delay :timer.minutes(5)

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Runs a prune now and returns its result. For tests and manual use."
  def run_now(server \\ __MODULE__), do: GenServer.call(server, :run_now, :timer.minutes(5))

  @impl true
  def init(opts) do
    config = Application.get_env(:trays_social, :error_reports, [])

    interval =
      Keyword.get(opts, :interval, Keyword.get(config, :prune_interval, @default_interval))

    initial_delay = Keyword.get(opts, :initial_delay, @default_initial_delay)

    Process.send_after(self(), :prune, initial_delay)
    {:ok, %{interval: interval}}
  end

  @impl true
  def handle_call(:run_now, _from, state), do: {:reply, safe_prune(), state}

  @impl true
  def handle_info(:prune, state) do
    safe_prune()
    Process.send_after(self(), :prune, state.interval)
    {:noreply, state}
  end

  defp safe_prune do
    ErrorReports.prune()
  rescue
    exception ->
      Logger.error("error_reports prune failed: #{Exception.message(exception)}")
      {:error, exception}
  end
end
