defmodule Uplink.Monitors do
  use Task

  alias Uplink.Cache
  alias Uplink.Pipelines
  alias Uplink.Clients.Instellar

  def start_link(options) do
    Task.start_link(__MODULE__, :run, options)
  end

  def run(options) do
    Instellar.list_monitors()
    |> case do
      {:ok, %{body: monitors}} ->
        state = maybe_start_pipeline(monitors)

      error ->
        {:error, error}
    end
  end

  defp maybe_start_pipeline(monitors) do
    Cache.transaction([keys: [:monitors]], fn ->
      started_monitors = Cache.get(:monitors)

      not_started_monitors =
        Enum.filter(monitors, fn monitor ->
          monitor["attributes"]["id"] not in started_monitors
        end)
    end)
  end
end
