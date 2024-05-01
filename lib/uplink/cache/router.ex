defmodule Uplink.Cache.Router do
  use Plug.Router, async: true
  use Uplink.Web

  alias Uplink.Secret
  alias Uplink.Cache

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
end
