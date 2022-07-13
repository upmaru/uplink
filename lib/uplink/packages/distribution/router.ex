defmodule Uplink.Packages.Distribution.Router do
  use Plug.Router

  alias Uplink.Packages.{
    Distribution
  }

  plug :match
  plug :dispatch

  forward "/distribution", to: Distribution

  get "/installs/:install_id/variables" do
  end

  match _ do
    send_resp(conn, 404, "not found")
  end
end
