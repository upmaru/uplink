defmodule Uplink.Metrics.Producer do
  use GenStage
  @behaviour Broadway.Producer

  alias Uplink.Cache
  alias Uplink.Metrics

  @doc false
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    state = %{
      demand: 0,
      poll_interval: Keyword.get(opts, :poll_interval, 15_000),
      previous_cpu_metrics: [],
      previous_network_metrics: []
    }

    {:producer, state}
  end

  @impl true
  def handle_demand(demand, state) when demand <= 0, do: {:noreply, [], state}

  def handle_demand(demand, state) do
    if ready_to_fetch?(state) do
      {messages, state} = load_metrics(demand, state)
      {:noreply, messages, state}
    else
      Process.send_after(self(), :poll, state.poll_interval)
      {:noreply, [], state}
    end
  end

  @impl true
  def handle_info(:poll, state) do
    if ready_to_fetch?(state) do
      {messages, state} = load_metrics(0, state)
      {:noreply, messages, state}
    else
      {:noreply, [], state}
    end
  end

  defp load_metrics(demand, state) do
    demand = demand + state.demand

    metrics = Metrics.for_instances()

    previous_cpu_metrics = state.previous_cpu_metrics
    previous_network_metrics = state.previous_network_metrics

    messages =
      transform_metrics(metrics, %{
        previous_cpu_metrics: previous_cpu_metrics,
        previous_network_metrics: previous_network_metrics
      })

    current_demand = demand - length(messages)

    fetch_timestamp =
      DateTime.to_unix(DateTime.utc_now(), :millisecond) |> IO.inspect()

    Cache.put({:monitors, :metrics, :last_fetched_timestamp}, fetch_timestamp)

    previous_cpu_metrics =
      Enum.map(metrics, fn instance ->
        %{
          name: instance.data.name,
          project: instance.data.project,
          timestamp: fetch_timestamp,
          data: Map.get(instance.data.state, "cpu")
        }
      end)

    previous_network_metrics =
      Enum.map(metrics, fn instance ->
        %{
          name: instance.data.name,
          project: instance.data.project,
          timestamp: fetch_timestamp,
          data: Map.get(instance.data.state, "network")
        }
      end)

    state =
      state
      |> Map.put(:demand, current_demand)
      |> Map.put(:last_fetched_timestamp, fetch_timestamp)
      |> Map.put(:previous_cpu_metrics, previous_cpu_metrics)
      |> Map.put(:previous_network_metrics, previous_network_metrics)

    {messages, state}
  end

  defp transform_metrics(metrics, %{
         previous_cpu_metrics: previous_cpu_metrics,
         previous_network_metrics: previous_network_metrics
       }) do
    metrics
    |> Enum.map(fn metric ->
      previous_cpu_metric =
        Enum.find(
          previous_cpu_metrics,
          &find_matching_previous(&1, metric.data.name, metric.data.project)
        )

      previous_network_metric =
        Enum.find(
          previous_network_metrics,
          &find_matching_previous(&1, metric.data.name, metric.data.project)
        )

      %{
        metric: metric,
        previous_network_metric: previous_network_metric,
        previous_cpu_metric: previous_cpu_metric
      }
    end)
    |> Enum.map(&transform_message/1)
  end

  defp transform_message(message) do
    %Broadway.Message{
      data: message,
      acknowledger: Broadway.NoopAcknowledger.init()
    }
  end

  defp ready_to_fetch?(state) do
    Cache.transaction(
      [keys: [{:monitors, :metrics, :last_fetched_timestamp}]],
      fn ->
        now = DateTime.to_unix(DateTime.utc_now(), :millisecond)

        last_fetched_timestamp =
          Cache.get({:monitors, :metrics, :last_fetched_timestamp})

        is_nil(last_fetched_timestamp) ||
          now - last_fetched_timestamp > state.poll_interval
      end
    )
  end

  defp find_matching_previous(metric, name, project) do
    metric.name == name && metric.project == project
  end
end
