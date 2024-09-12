defmodule Uplink.Packages.Instance.Placement do
  alias Uplink.Cache
  alias Uplink.Clients.LXD

  defstruct [:node]

  def name(node_name) do
    node_name
    |> String.split("-")
    |> List.delete_at(-1)
    |> Enum.join("-")
  end

  def find(node_name, "spread") do
    placement_name = name(node_name)

    Cache.get({:available_nodes, placement_name})
    |> case do
      nil ->
        available_nodes =
          LXD.list_instances()
          |> Enum.group_by(fn instance ->
            instance.location
          end)
          |> Enum.reject(fn {_k, instances} ->
            Enum.any?(instances, fn instance ->
              String.starts_with?(instance.name, placement_name)
            end)
          end)
          |> Enum.map(fn {k, _} -> k end)
          |> Enum.map(fn n -> n end)

        Cache.put({:available_nodes, placement_name}, available_nodes)

        available_nodes

      available_nodes ->
        available_nodes
    end
    |> List.first()
    |> case do
      node when is_binary(node) ->
        {:ok, %__MODULE__{node: node}}

      nil ->
        find(node_name, "auto")
    end
  end

  def find(_name, _) do
    frequency =
      LXD.list_instances()
      |> Enum.frequencies_by(fn instance ->
        instance.location
      end)

    selected_member =
      LXD.list_cluster_members()
      |> Enum.min_by(fn m -> frequency[m.server_name] || 0 end)

    {:ok, %__MODULE__{node: selected_member.server_name}}
  end
end
