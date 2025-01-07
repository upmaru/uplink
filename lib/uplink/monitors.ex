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
    Pipelines.reset_monitors(:metrics)

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

    grouped_monitors =
      Enum.group_by(monitors, fn monitor ->
        monitor["attributes"]["type"]
      end)

    context_monitors = Map.get(grouped_monitors, "#{context}") || []

    Pipelines.update_monitors(context, context_monitors)

    module = Map.fetch!(@pipeline_modules, context)

    Pipelines.start(module)
  end

  def config(key, default) do
    configuration = Application.get_env(:uplink, __MODULE__) || []

    Keyword.get(configuration, key, default)
  end
end
