defmodule Uplink.Cache.Router do
  use Plug.Router
  use Uplink.Web

  alias Uplink.Secret
  alias Uplink.Cache
  alias Uplink.Routings

  plug :match

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    body_reader: {Uplink.Web.CacheBodyReader, :read_body, []},
    json_decoder: Jason

  plug Secret.VerificationPlug

  plug :dispatch

  delete "/self" do
    Cache.transaction([keys: [:self]], fn ->
      Cache.delete(:self)
    end)

    json(conn, :ok, %{message: "cache key :self deleted."})
  end

  delete "/routers/:router_id/proxies" do
    router_id = String.to_integer(router_id)

    Cache.transaction([keys: [{:proxies, router_id}]], fn ->
      Cache.delete({:proxies, router_id})
      Routings.list_proxies(router_id)
    end)

    json(conn, :ok, %{message: "cache key {:proxies, #{router_id}} refreshed."})
  end
end
