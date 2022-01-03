defmodule Uplink.Router do
  use Plug.Router
  
  plug Plug.Static,
    at: "/distribution",
    from: "tmp/deployments"

  plug :match
  plug :dispatch

  alias Uplink.Packages.Deployment


  forward("/deployments", to: Deployment.Router)
end
