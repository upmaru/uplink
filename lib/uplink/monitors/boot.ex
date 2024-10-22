defmodule Uplink.Monitors.Boot do
  use Task

  alias Uplink.Clients.Instellar

  require Logger

  def init(args) do
    Task.start_link(__MODULE__, :run, [args])
  end

  def run(args) do
    case Instellar.list_monitors() do
      {:ok, monitors} ->
        nil

      {:error, error} ->
        Logger.error("Failed to find monitors: #{inspect(error)}")
    end
  end
end
