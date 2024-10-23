defmodule Uplink.Monitors.Pipeline do
  use Broadway

  alias Broadway.Message
  alias Uplink.Monitors.Metric

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {Uplink.Monitors.Producer, [poll_interval: :timer.seconds(15)]},
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

    memory = Metric.memory(instance_metric)
    cpu = Metric.cpu(instance_metric, previous_cpu_metric)

    Message.put_data(message, %{memory: memory, cpu: cpu})
  end

  def handle_batch(_, messages, _batch_info, _context) do
    IO.inspect(messages)

    messages
  end
end
