defmodule Uplink.Packages.Instance.Placement do
  alias Uplink.Cache
  alias Uplink.Clients.LXD

  def find(_name, "auto") do
    frequency =
      LXD.list_instances()
      |> Enum.frequencies_by(fn instance ->
        instance.location
      end)

    LXD.list_cluster_members()
    |> Enum.min_by(fn m -> frequency[m.server_name] || 0 end)
  end

  def find(name, "spread") do
    placement_name =
      String.split(name, "-")
      |> List.delete_at(-1)
      |> Enum.join("-")

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
          |> Enum.map(fn n -> %{server_name: n} end)

        Cache.put({:available_nodes, placement_name}, available_nodes)

        available_nodes

      available_nodes ->
        available_nodes
    end
  end
end
