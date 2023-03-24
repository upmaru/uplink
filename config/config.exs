import Config

config :uplink, Uplink.Cache,
  primary: [
    gc_interval: 3_600_000,
    backend: :shards
  ]

config :uplink, Uplink.Internal, port: 4080

config :uplink, Uplink.Router, port: 4040

config :uplink, Uplink.Clients.Caddy,
  endpoint: System.get_env("CADDY_ADMIN_ENDPOINT", "http://localhost:2019"),
  zero_ssl_api_key: System.get_env("ZERO_SSL_API_KEY", ""),
  storage: %{
    prefix: "uplink"
  }

config :uplink, Uplink.Repo, prepare: :unnamed

config :uplink, Oban,
  repo: Uplink.Repo,
  peer: Oban.Peers.Global,
  notifier: Oban.Notifiers.PG,
  log: false,
  queues: [
    install: 1,
    deployment: 1,
    instance: 1,
    caddy: 1
  ]

config :logger,
  backends: [:console]

config :logger, :console, format: "[$level] $message\n"

config :uplink, Uplink.Cluster,
  installation_id: System.get_env("UPLINK_INSTALLATION_ID")

config :uplink, Uplink.Secret, System.get_env("UPLINK_SECRET")

config :uplink, ecto_repos: [Uplink.Repo]

import_config "#{Mix.env()}.exs"
