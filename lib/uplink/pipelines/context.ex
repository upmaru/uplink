defmodule Uplink.Pipelines.Context do
  use Agent

  require Logger

  def start_link(options) do
    monitors = Keyword.get(options, :monitors, [])
    name = Keyword.fetch!(options, :name)

    Agent.start_link(fn -> monitors end, name: {:global, name})
    |> case do
      {:ok, pid} ->
        Logger.info("[Uplink.Pipelines.Context] started #{inspect(name)}")

        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Process.link(pid)
        {:ok, pid}
    end
  end

  def get(pid_or_name) do
    Agent.get({:global, pid_or_name}, fn monitors -> monitors end)
  end

  def append(pid_or_name, new_monitors) do
    Agent.get_and_update({:global, pid_or_name}, fn monitors ->
      {monitors, monitors ++ new_monitors}
    end)
  end
end
