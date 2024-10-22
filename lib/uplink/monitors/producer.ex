defmodule Uplink.Monitors.Producer do
  use GenStage
  @behaviour Broadway.Producer

  alias Uplink.Metrics

  @doc false
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    state = %{
      client: LXD.client(),
      demand: 0,
      poll_interval: Keyword.get(opts, :poll_interval, 15_000)
    }

    {:producer, state}
  end

  @impl true
  def handle_demand(demand, state) do
    {messages, state} = load_metrics(demand, state)
    {:noreply, messages, state}
  end

  def handle_info(:poll, state) do
    {messages, state} = load_metrics(0, state)
    Process.send_after(self(), :poll, state.poll_interval)
  end

  defp load_metrics(demand, state) when demand <= 0, do: {[], state}

  defp load_metrics(demand, state) do
    messages =
      Metrics.get_instances_metrics()
      |> transform_metrics()

    {messages, %{state | demand: demand - Enum.count(messages)}}
  end

  defp transform_metrics(metrics) do
    Enum.map(metrics, &transform_message/1)
  end

  defp transform_message(message) do
    %Broadway.Message{
      data: message,
      acknowledger: Broadway.NoopAcknowledger.init()
    }
  end
end
