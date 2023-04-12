defmodule Uplink.Clients.LXD.Network.Manager do
  alias Uplink.{
    Cache,
    Clients
  }

  alias Clients.LXD
  alias LXD.Network

  def leases(project) do
    with %Network{name: name} <- managed(),
         {:ok, %{body: leases}} <-
           LXD.client()
           |> Lexdee.list_network_leases(name, query: [project: project]) do
      Enum.map(leases, fn lease ->
        Network.Lease.parse(lease)
      end)
    else
      error -> error
    end
  end

  def managed do
    Cache.get({:networks, "managed"}) ||
      LXD.client()
      |> Lexdee.list_networks(query: [recursion: 1])
      |> case do
        {:ok, %{body: networks}} ->
          network =
            networks
            |> Enum.map(fn network ->
              Network.parse(network)
            end)
            |> Enum.find(fn network ->
              network.managed
            end)

          Cache.put({:networks, "managed"}, network)

          network

        error ->
          error
      end
  end
end
