use Mix.Config

config :uplink, Uplink.Cache,
  primary: [
    gc_interval: 3_600_000,
    backend: :shards
  ]

config :uplink, Uplink.Secret, System.get_env("UPLINK_SECRET")

config :uplink, ecto_repos: [Uplink.Repo]

import_config "#{Mix.env()}.exs"
