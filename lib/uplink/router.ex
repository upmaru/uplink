defmodule Uplink.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  alias Uplink.Packages.Deployment

  forward("/deployments", to: Deployment.Router)
end
