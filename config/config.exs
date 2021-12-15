use Mix.Config

config :uplink, Uplink.Cache,
  primary: [
    gc_interval: 3_600_000,
    backend: :shards
  ]

config :uplink, Uplink.Secret, System.get_env("UPLINK_SECRET")

config :uplink, ecto_repos: [Uplink.Repo]

config :uplink, Uplink.Repo,
  database: System.get_env("UPLINK_DB_NAME"),
  username: System.get_env("UPLINK_DB_USERNAME"),
  password: System.get_env("UPLINK_DB_PASSWORD"),
  hostname: System.get_env("UPLINK_DB_HOST")

import_config "#{Mix.env()}.exs"
