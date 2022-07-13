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

  match _ do
    send_resp(conn, 404, "not found")
  end
end
