defmodule Uplink.Router do
  use Plug.Router
  use Uplink.Web

  alias Uplink.Packages.{
    Instance,
    Deployment
  }

  plug :match
  plug :dispatch

  get "/health" do
    json(conn, :ok, %{message: "Live long and prosper."})
  end

  forward "/deployments", to: Deployment.Router
  forward "/instances", to: Instance.Router

  match _ do
    send_resp(conn, 404, "not found")
  end
end
