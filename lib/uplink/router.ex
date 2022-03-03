defmodule Uplink.Router do
  use Plug.Router
  use Uplink.Web

  alias Uplink.Packages.{
    Instance,
    Deployment,
    Distribution
  }

  plug :match
  plug :dispatch

  get "/health" do
    json(conn, :ok, %{message: "Live long, and prosper."})
  end

  forward "/distribution", to: Distribution
  forward "/deployments", to: Deployment.Router
  forward "/instances", to: Instance.Router
end
