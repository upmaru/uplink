defmodule Uplink.Application do
  @moduledoc false

  use Application

  alias Uplink.Web

  @pipeline_supervisor Uplink.PipelineSupervisor

  require Logger

  def start(_type, _args) do
    %{key: key, cert: cert} = Web.Certificate.generate()

    pipeline_supervisor_config =
      Application.get_env(:uplink, @pipeline_supervisor, [])

    sync_interval =
      Keyword.get(pipeline_supervisor_config, :sync_interval, 5_000)

    router_config = Application.get_env(:uplink, Uplink.Router, port: 4040)

    internal_router_config =
      Application.get_env(:uplink, Uplink.Internal, port: 4080)

    port = Keyword.get(router_config, :port)
    internal_port = Keyword.get(internal_router_config, :port)

    topologies = Application.get_env(:libcluster, :topologies, [])

    children =
      if System.get_env("MIX_TASK") == "opsmo.embed" do
        Logger.info("Running opsmo.embed not starting entire application...")

        []
      else
        [
          {Uplink.Cache, []},
          {Cluster.Supervisor, [topologies, [name: Uplink.ClusterSupervisor]]},
          {Task.Supervisor, name: Uplink.TaskSupervisor},
          {Plug.Cowboy,
           plug: Uplink.Internal, scheme: :http, port: internal_port},
          {Pogo.DynamicSupervisor,
           name: @pipeline_supervisor,
           scope: :uplink,
           sync_interval: sync_interval},
          {Uplink.Monitors, []},
          {
            Plug.Cowboy,
            plug: Uplink.Router,
            scheme: :https,
            port: port,
            key: {:RSAPrivateKey, key},
            cert: cert
          },
          {Uplink.Data.Provisioner, []},
          Opsmo.spec(Opsmo.CRPM)
        ]
      end

    opts = [strategy: :one_for_one, name: Uplink.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
