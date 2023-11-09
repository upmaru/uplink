defmodule Uplink.Internal do
  use Plug.Router
  use Uplink.Web

  alias Uplink.{
    Packages
  }

  alias Packages.{
    Distribution,
    Install
  }

  plug :match
  plug :dispatch

  forward "/distribution", to: Distribution
  forward "/installs", to: Install.Router

  get "/caddy" do
    config = Uplink.Clients.Caddy.build_new_config()

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(:ok, Jason.encode!(config))
  end

  match _ do
    send_resp(conn, 404, "not found")
  end
end
