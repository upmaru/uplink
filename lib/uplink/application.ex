defmodule Uplink.Application do
  @moduledoc false

  use Application

  alias Uplink.Web

  def start(_type, _args) do
    %{key: key, cert: cert} = Web.Certificate.generate()
    router_config = Application.get_env(:uplink, Uplink.Router, port: 4040)

    internal_router_config =
      Application.get_env(:uplink, Uplink.Internal, port: 4080)

    port = Keyword.get(router_config, :port)
    internal_port = Keyword.get(internal_router_config, :port)

    topologies = Application.get_env(:libcluster, :topologies, [])

    children = [
      {Uplink.Cache, []},
      {Cluster.Supervisor, [topologies, [name: Uplink.ClusterSupervisor]]},
      {Task.Supervisor, name: Uplink.TaskSupervisor},
      {Plug.Cowboy, plug: Uplink.Internal, scheme: :http, port: internal_port},
      {
        Plug.Cowboy,
        plug: Uplink.Router,
        scheme: :https,
        port: port,
        key: {:RSAPrivateKey, key},
        cert: cert
      },
      {Uplink.Data.Provisioner, []}
    ]

    opts = [strategy: :one_for_one, name: Uplink.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
