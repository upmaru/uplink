defmodule Uplink.Nodes.Router do
  use Plug.Router
  use Uplink.Web

  alias Uplink.Secret
  alias Uplink.Clients.LXD

  plug :match

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    body_reader: {Uplink.Web.CacheBodyReader, :read_body, []},
    json_decoder: Jason

  plug Secret.VerificationPlug

  plug :dispatch

  post "/" do
    nodes =
      LXD.list_cluster_members()
      |> Enum.map(fn member ->
        LXD.get_node(member.server_name)
      end)

    json(conn, :ok, %{data: nodes})
  end
end
