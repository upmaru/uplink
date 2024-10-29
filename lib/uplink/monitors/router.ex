defmodule Uplink.Monitors.Router do
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

  post "/refresh" do
    Uplink.Monitors.run()

    json(conn, :ok, %{message: "monitors refreshed."})
  end
end
