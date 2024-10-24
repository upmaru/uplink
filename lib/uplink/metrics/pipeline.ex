defmodule Uplink.Metrics.Pipeline do
  use Broadway

  alias Broadway.Message

  alias Uplink.Metrics
  alias Uplink.Metrics.Document

  def start_link(opts) do
    monitor = Keyword.fetch!(opts, :monitor)

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      context: %{
        monitor: monitor
      },
      producer: [
        module: {Uplink.Metrics.Producer, [poll_interval: :timer.seconds(15)]},
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
  end

  def handle_message(_, %Message{data: data} = message, _) do
    %{metric: instance_metric, previous_cpu_metric: previous_cpu_metric} = data

    memory = Document.memory(instance_metric)
    cpu = Document.cpu(instance_metric, previous_cpu_metric)
    uptime = Document.uptime(instance_metric)
    filesystem = Document.filesystem(instance_metric)
    diskio = Document.diskio(instance_metric)

    data = %{
      memory: memory,
      cpu: cpu,
      uptime: uptime,
      filesystem: filesystem,
      diskio: diskio
    }

    Message.put_data(message, data)
  end

  def handle_batch(_, messages, _batch_info, context) do
    documents = to_ndjson(messages)

    Metrics.push!(context.monitor, documents) |> IO.inspect()

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
    |> Enum.flat_map(fn {type, data} ->
      index = Metrics.index(type)
      metadata = %{"create" => %{"_index" => index}}

      [metadata, data]
    end)
  end
end
