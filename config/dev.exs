import Config

config :uplink, Uplink.Secret, "secretsomethingsixteen"

config :uplink, Uplink.Clients.Instellar, endpoint: "http://localhost/uplink"

config :uplink, Uplink.Repo,
  database: System.get_env("UPLINK_DB_NAME", "uplink_dev"),
  username: System.get_env("UPLINK_DB_USERNAME"),
  password: System.get_env("UPLINK_DB_PASSWORD"),
  hostname: System.get_env("UPLINK_DB_HOST") || "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
