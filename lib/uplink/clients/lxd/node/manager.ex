defmodule Uplink.Clients.LXD.Node.Manager do
  alias Uplink.Cache
  alias Uplink.Clients.LXD
  alias Uplink.Clients.LXD.Node

  def show(name) do
    Cache.get({:node, name}) || fetch_node(name)
  end

  defp fetch_node(name) do
    LXD.client()
    |> Lexdee.show_resources(name)
    |> case do
      {:ok, %{body: node}} ->
        %{
          "cpu" => %{"total" => total_cores_count},
          "memory" => %{"total" => total_memory},
          "storage" => %{"disks" => disks}
        } = node

        disk_sizes =
          Enum.map(disks, fn disk ->
            disk["size"]
          end)
          |> Enum.sum()

        Node.parse(%{
          name: name,
          cpu_cores_count: total_cores_count,
          total_memory: total_memory,
          total_storage: disk_sizes
        })

      error ->
        error
    end
  end
end
