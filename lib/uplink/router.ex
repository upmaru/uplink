defmodule Uplink.Router do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  plug(Plug.Parsers,
    parsers: [:urldecoder, :json],
    json_decoder: Jason
  )

  alias Uplink.Packages.Deployment

  forward("/deployments", to: Deployment.Router)
end
