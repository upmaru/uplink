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

  post "/" do
    Uplink.Monitors.run()

    json(conn, :ok, %{message: "monitors updated."})
  end
end
