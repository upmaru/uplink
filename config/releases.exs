import Config

config :uplink, Uplink.Repo, url: System.get_env("DATABASE_URL")

config :uplink, Uplink.Clients.Instellar,
  endpoint:
    System.get_env("INSTELLAR_ENDPOINT", "https://web.instellar.app/uplink")

config :uplink, Uplink.Cluster,
  installation_id: System.get_env("UPLINK_INSTALLATION_ID")

config :uplink, Uplink.Secret, System.get_env("UPLINK_SECRET")
