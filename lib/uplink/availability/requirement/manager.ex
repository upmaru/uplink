defmodule Uplink.Availability.Requirement.Manager do
  alias Uplink.Clients.LXD

  alias Uplink.Availability.Requirement

  def process(params) do
    %{"project" => project, "cpu" => cpu, "memory" => memory, "disk" => disk} =
      params

    instance_names =
      LXD.list_instances(project: project)
      |> Enum.map(fn instance ->
        instance.name
      end)

    LXD.list_cluster_members()
    |> Enum.map(fn member ->
      LXD.get_node(member.server_name)
    end)
    |> Enum.map(fn node ->
      %{
        "node" => node.name,
        "instances" => instance_names,
        "cpu" => normalize(cpu, node.cpu_cores_count),
        "memory" => normalize(memory, node.total_memory),
        "disk" => normalize(disk, node.total_storage)
      }
    end)
    |> Enum.map(&Requirement.parse(&1))
  end

  defp normalize(required, total) do
    Decimal.div(Decimal.new(required), Decimal.new(total))
  end
end
