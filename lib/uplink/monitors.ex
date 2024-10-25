defmodule Uplink.Monitors do
  use Task

  alias Uplink.Pipelines
  alias Uplink.Clients.Instellar

  require Logger

  @pipeline_modules %{
    metrics: Uplink.Metrics.Pipeline
  }

  def start_link(options) do
    Task.start_link(__MODULE__, :run, [options])
  end

  def run(_options) do
    Instellar.list_monitors()
    |> case do
      {:ok, monitors} ->
        start_pipeline(monitors, :metrics)

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
end
