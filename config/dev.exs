import Config

config :uplink,
       Uplink.Secret,
       System.get_env("UPLINK_SECRET", "secretsomethingsixteen")

config :uplink, Uplink.Data, mode: "lite"

config :uplink, Uplink.Clients.Instellar,
  endpoint: "http://localhost:4000/uplink"

config :uplink, :environment, :dev

config :uplink, Uplink.Repo,
  database: System.get_env("UPLINK_DB_NAME", "uplink_dev"),
  username: System.get_env("UPLINK_DB_USERNAME", "postgres"),
  password: System.get_env("UPLINK_DB_PASSWORD"),
  hostname: System.get_env("UPLINK_DB_HOST") || "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
