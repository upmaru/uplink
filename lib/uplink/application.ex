defmodule Uplink.Application do
  @moduledoc false

  use Application

  alias Uplink.Web

  def start(_type, _args) do
    oban_config = Application.fetch_env!(:uplink, Oban)
    %{key: key, cert: cert} = Web.Certificate.generate()
    router_config = Application.get_env(:uplink, Uplink.Router, port: 4040)

    internal_router_config =
      Application.get_env(:uplink, Uplink.Internal, port: 4080)

    port = Keyword.get(router_config, :port)
    internal_port = Keyword.get(internal_router_config, :port)

    children =
      [
        {Uplink.Cache, []},
        {Uplink.Repo, []},
        {Oban, oban_config},
        {Plug.Cowboy,
         plug: Uplink.Internal, scheme: :http, port: internal_port},
        {
          Plug.Cowboy,
          plug: Uplink.Router,
          scheme: :https,
          port: port,
          key: {:RSAPrivateKey, key},
          cert: cert
        }
      ]
      |> append_live_only_services(Application.get_env(:uplink, :environment))

    opts = [strategy: :one_for_one, name: Uplink.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp append_live_only_services(children, :test),
    do: children

  defp append_live_only_services(children, _),
    do: children ++ [{Uplink.Boot, []}]
end
