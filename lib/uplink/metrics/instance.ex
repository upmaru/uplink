defmodule Uplink.Metrics.Instance do
  alias Uplink.Clients.LXD
  alias Uplink.Clients.Instellar

  defstruct [:name, :cycle, :timestamp, :data, :node, :metrics, :account]

  def metrics do
    instances = LXD.list_instances(recursion: 2)
    metrics = LXD.list_metrics()
    %{"organization" => %{"slug" => account_id}} = Instellar.get_self()

    metrics =
      metrics
      |> Enum.filter(fn line ->
        line.label in [
          "lxd_disk_read_bytes_total",
          "lxd_disk_reads_completed_total",
          "lxd_disk_written_bytes_total",
          "lxd_disk_writes_completed_total",
          "lxd_memory_Cached_bytes"
        ] && line.value != "0"
      end)
      |> Enum.group_by(fn line ->
        pairs_map = Enum.into(line.pairs, %{})

        {Map.get(pairs_map, "name"), Map.get(pairs_map, "project")}
      end)

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

      lxd_metrics =
        Enum.find(metrics, fn {{name, project}, _m} ->
          name == instance.name and project == instance.project
        end)
        |> case do
          {_, metrics} -> metrics
          nil -> []
        end

      %__MODULE__{
        name: instance.name,
        data: instance,
        node: node,
        account: %{
          id: account_id
        },
        metrics: lxd_metrics,
        timestamp: DateTime.utc_now()
      }
    end)
  end
end
