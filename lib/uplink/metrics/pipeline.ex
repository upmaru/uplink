defmodule Uplink.Metrics.Pipeline do
  use Broadway

  alias Broadway.Message

  alias Uplink.Pipelines

  alias Uplink.Metrics
  alias Uplink.Metrics.Document

  require Logger

  def start_link(_opts \\ []) do
    configuration = Application.get_env(:uplink, __MODULE__) || []

    producer_module =
      Keyword.get(configuration, :producer_module, Uplink.Metrics.Producer)

    producer_options =
      Keyword.get(configuration, :producer_options,
        poll_interval: :timer.seconds(15)
      )

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      context: :metrics,
      producer: [
        module: {producer_module, producer_options},
        concurrency: 1
      ],
      processors: [
        default: [
          concurrency: 3,
          max_demand: 10
        ]
      ],
      batchers: [
        default: [
          concurrency: 3,
          batch_size: 10
        ]
      ]
    )
    |> case do
      {:ok, pid} ->
        Logger.info("[Uplink.Metrics.Pipeline] Started...")

        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Process.link(pid)
        {:ok, pid}
    end
  end

  def handle_message(_, %Message{data: data} = message, _) do
    %{
      metric: instance_metric,
      previous_cpu_metric: previous_cpu_metric,
      previous_network_metric: previous_network_metric,
      cpu_60_metric: cpu_60_metric,
      cpu_300_metric: cpu_300_metric,
      cpu_900_metric: cpu_900_metric
    } = data

    memory = Document.memory(instance_metric)
    cpu = Document.cpu(instance_metric, previous_cpu_metric)
    uptime = Document.uptime(instance_metric)
    filesystem = Document.filesystem(instance_metric)
    diskio = Document.diskio(instance_metric)
    network = Document.network(instance_metric, previous_network_metric)

    load =
      Document.load(instance_metric, %{
        cpu_60_metric: cpu_60_metric,
        cpu_300_metric: cpu_300_metric,
        cpu_900_metric: cpu_900_metric
      })

    data = %{
      memory: memory,
      cpu: cpu,
      uptime: uptime,
      filesystem: filesystem,
      diskio: diskio,
      network: network,
      load: load
    }

    Message.put_data(message, data)
  end

  def handle_batch(_, messages, _batch_info, context) do
    documents = to_ndjson(messages)
    monitors = Pipelines.get_monitors(context)

    Logger.info("[Metrics.Pipeline] pushing #{DateTime.utc_now()}")

    monitors
    |> Enum.map(fn monitor ->
      Metrics.push!(monitor, documents)
    end)

    messages
  end

  defp to_ndjson(messages) do
    documents =
      Enum.flat_map(messages, &to_entry/1)
      |> Enum.map(&Jason.encode!/1)
      |> Enum.join("\n")

    documents <> "\n"
  end

  defp to_entry(%Message{} = message) do
    dataset =
      message.data
      |> Enum.to_list()
      |> Enum.reject(fn {_key, value} ->
        is_nil(value)
      end)

    dataset
    |> Enum.flat_map(&build_request/1)
  end

  defp build_request({type, data}) when is_list(data) do
    index = Metrics.index(type)

    Enum.reduce(data, [], fn entry, acc ->
      metadata = %{"create" => %{"_index" => index}}

      [metadata, entry | acc]
    end)
  end

  defp build_request({type, data}) when is_map(data) do
    index = Metrics.index(type)
    metadata = %{"create" => %{"_index" => index}}

    [metadata, data]
  end
end
