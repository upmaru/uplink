defmodule Uplink.Application do
  @moduledoc false

  use Application

  alias Uplink.Web

  def start(_type, _args) do
    oban_config = Application.fetch_env!(:uplink, Oban)
    %{key: key, cert: cert} = Web.Certificate.generate()
    router_config = Application.get_env(:uplink, Uplink.Router, port: 4040)
    port = Keyword.get(router_config, :port)

    children = [
      {Uplink.Cache, []},
      {Uplink.Repo, []},
      {Oban, oban_config},
      {
        Plug.Cowboy,
        plug: Uplink.Router,
        scheme: :https,
        port: port,
        key: {:RSAPrivateKey, key},
        cert: cert
      }
    ]

    opts = [strategy: :one_for_one, name: Uplink.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
