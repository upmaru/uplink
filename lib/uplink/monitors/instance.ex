defmodule Uplink.Monitors.Instance do
  alias Uplink.Clients.LXD

  defstruct [:name, :timestamp, :data, :node, :monitor]

  def metrics do
    instances = LXD.list_instances(recursion: 2)

    nodes =
      instances
      |> Enum.map(fn instance ->
        instance.location
      end)
      |> Enum.uniq()

    nodes =
      Enum.map(nodes, fn node ->
        LXD.get_node(node)
      end)

    instances
    |> Enum.map(fn instance ->
      node =
        Enum.find(nodes, fn node ->
          node.name == instance.location
        end)

      %__MODULE__{
        name: instance.name,
        data: instance,
        node: node,
        timestamp: DateTime.utc_now()
      }
    end)
  end
end
