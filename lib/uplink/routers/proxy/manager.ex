defmodule Uplink.Routers.Proxy.Manager do
  alias Uplink.Cache
  alias Uplink.Clients.Instellar

  def list(router_id) do
    Cache.get({:proxies, router_id})
    |> case do
      nil ->
        fetch_proxies_list(router_id)

      proxies when is_list(proxies) ->
        proxies
    end
  end

  defp fetch_proxies_list()
end