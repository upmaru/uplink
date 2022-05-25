import Mix.Config

config :uplink, Uplink.Repo, url: System.get_env("DATABASE_URL")

config :uplink, Uplink.Cluster,
  installation_id: System.get_env("UPLINK_INSTALLATION_ID")

config :uplink, Uplink.Secret, System.get_env("UPLINK_SECRET")
