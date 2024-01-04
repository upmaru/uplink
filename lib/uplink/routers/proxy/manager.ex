defmodule Uplink.Routers.Proxy.Manager do
  alias Uplink.Cache
  alias Uplink.Clients.Instellar

  alias Uplink.Routers.Proxy

  def list(router_id) do
    Cache.get({:proxies, router_id})
    |> case do
      nil ->
        fetch_proxies_list(router_id)

      proxies when is_list(proxies) ->
        proxies
    end
  end

  defp fetch_proxies_list(router_id) do
    case Instellar.list_proxies(router_id) do
      {:ok, proxies_params} ->
        proxies =
          proxies_params
          |> Enum.map(fn params ->
            Proxy.create!(params)
          end)

        Cache.put({:proxies, router_id}, proxies)

        proxies

      {:error, _error} ->
        []
    end
  end
end
