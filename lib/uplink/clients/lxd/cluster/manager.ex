defmodule Uplink.Clients.LXD.Cluster.Manager do
  alias Uplink.{
    Cache,
    Clients
  }

  alias Clients.LXD
  alias LXD.Cluster
  alias Cluster.Member

  def list_members do
    Cache.get(:cluster_members) ||
      LXD.client()
      |> Lexdee.list_cluster_members(query: [recursive: 1])
      |> case do
        {:ok, %{body: members}} ->
          members =
            members
            |> Enum.map(fn member ->
              Member.parse(member)
            end)

          Cache.put(:cluster_members, members)

          members

        error ->
          error
      end
  end
end
