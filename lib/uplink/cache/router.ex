defmodule Uplink.Cache.Router do
  use Plug.Router
  use Uplink.Web

  alias Uplink.Secret

  plug :match

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    body_reader: {Uplink.Web.CacheBodyReader, :read_body, []},
    json_decoder: Jason

  plug Secret.VerificationPlug

  plug :dispatch

  delete "/self" do
    Uplink.Cache.delete(:self)

    json(conn, :ok, %{message: "cache key :self deleted."})
  end
end
