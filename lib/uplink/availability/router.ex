defmodule Uplink.Availability.Router do
  use Plug.Router
  use Uplink.Web

  alias Uplink.Secret
  alias Uplink.Availability

  plug :match

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    body_reader: {Uplink.Web.CacheBodyReader, :read_body, []},
    json_decoder: Jason

  plug Secret.VerificationPlug

  plug :dispatch

  post "/resources" do
    case Availability.check!() do
      {:ok, resources} ->
        json(conn, :ok, resources)

      {:error, reason} ->
        json(conn, :service_unavailable, %{error: %{message: reason}})
    end
  end
end
