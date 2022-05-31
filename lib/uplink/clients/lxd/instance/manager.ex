defmodule Uplink.Clients.LXD.Instance.Manager do
  alias Uplink.{
    Cache,
    Clients
  }

  alias Clients.LXD
  alias LXD.Instance

  def list do
    Cache.get(:instances) ||
      LXD.client()
      |> Lexdee.list_instances(query: [recursion: 1])
      |> case do
        {:ok, %{body: instances}} ->
          instances =
            instances
            |> Enum.map(fn instance ->
              Instance.parse(instance)
            end)

          Cache.put(:instances, instances)

          instances

        error ->
          error
      end
  end
end
