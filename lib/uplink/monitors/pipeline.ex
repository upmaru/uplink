defmodule Uplink.Monitors.Pipeline do
  use Broadway

  alias Broadway.Message

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {Uplink.Monitors.Producer, [poll_interval: :timer.seconds(15)]},
        cncurrency: 1
      ],
      processors: [
        default: [
          concurrency: 1
        ]
      ]
    )
  end
end
