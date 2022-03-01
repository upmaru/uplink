defmodule Uplink.Router do
  use Plug.Router

  alias Uplink.Packages.{
    Deployment,
    Distribution
  }

  plug :match
  plug :dispatch

  forward "/distribution", to: Distribution
  forward "/deployments", to: Deployment.Router
  forward "/instances", to: Packages.Instance.Router
end
