defmodule Uplink.Monitors.Observer do
  use GenStage

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_options) do
    schedule_initial_job()

    {:ok, %{}}
  end

  def handle_info(:perform, state) do


  defp schedule_initial_job() do
    # In 5 seconds
    Process.send_after(self(), :perform, 5_000)
  end
end
