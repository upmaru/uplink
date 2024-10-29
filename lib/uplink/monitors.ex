defmodule Uplink.Monitors do
  use Task

  alias Uplink.Cache
  alias Uplink.Pipelines
  alias Uplink.Clients.Instellar

  require Logger

  @pipeline_modules %{
    metrics: Uplink.Metrics.Pipeline
  }

  def start_link(options) do
    enabled? = config(:enabled, true)

    if enabled? do
      Task.start_link(__MODULE__, :run, [options])
    else
      :ignore
    end
  end

  def run(_options \\ []) do
    Cache.put_new({:monitors, :metrics}, [])

    Instellar.list_monitors()
    |> case do
      {:ok, monitors} ->
        Cache.transaction([keys: [{:monitors, :metrics}]], fn ->
          start_pipeline(monitors, :metrics)
        end)

      error ->
        {:error, error}
    end
  end

  defp start_pipeline(monitors, context) do
    Logger.info("[Uplink.Monitors] Starting pipeline...")

    started_metrics_monitor_ids =
      Pipelines.get_monitors(context)
      |> Enum.map(fn monitor ->
        monitor["attributes"]["id"]
      end)

    not_started_monitors =
      Enum.filter(monitors, fn monitor ->
        monitor["attributes"]["id"] not in started_metrics_monitor_ids
      end)

    grouped_monitors =
      Enum.group_by(not_started_monitors, fn monitor ->
        monitor["attributes"]["type"]
      end)

    context_monitors = Map.get(grouped_monitors, "#{context}")

    if Enum.count(context_monitors) > 0 do
      Pipelines.append_monitors(context, context_monitors)
    end

    module = Map.fetch!(@pipeline_modules, context)

    Pipelines.start(module)
  end

  def config(key, default) do
    configuration = Application.get_env(:uplink, __MODULE__) || []

    Keyword.get(configuration, key, default)
  end
end
