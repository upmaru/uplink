defmodule Uplink.Availability.Requirement.Manager do
  alias Uplink.Clients.LXD

  alias Uplink.Availability.Requirement
  alias Uplink.Availability.Requirement.Params

  def process(params) do
    case Params.parse(params) do
      {:ok, %Params{} = params} ->
        instance_names =
          LXD.list_instances(project: params.project)
          |> Enum.map(fn instance ->
            instance.name
          end)

        requirements =
          LXD.list_cluster_members()
          |> Enum.map(fn member ->
            LXD.get_node(member.server_name)
          end)
          |> Enum.map(fn node ->
            %{
              "node" => node.name,
              "instances" => instance_names,
              "cpu" => normalize(params.cpu, node.cpu_cores_count),
              "memory" => normalize(params.memory, node.total_memory),
              "disk" => normalize(params.disk, node.total_storage)
            }
          end)
          |> Enum.map(&Requirement.parse(&1))

        {:ok, requirements}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp normalize(required, total) do
    Decimal.div(required, Decimal.new(total))
  end
end
