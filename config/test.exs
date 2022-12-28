import Config

config :uplink, Uplink.Repo,
  username:
    System.get_env("UPLINK_DB_USERNAME") || System.get_env("POSTGRES_USERNAME"),
  password:
    System.get_env("UPLINK_DB_PASSWORD") || System.get_env("POSTGRES_PASSWORD"),
  hostname:
    System.get_env("UPLINK_DB_HOST") || System.get_env("POSTGRES_HOST") ||
      "localhost",
  database: "uplink_test",
  queue_target: 50_000,
  queue_interval: 50_000,
  pool: Ecto.Adapters.SQL.Sandbox

config :uplink, Uplink.Clients.Caddy,
  zero_ssl_api_key: System.get_env("ZERO_SSL_API_KEY", ""),
  storage: %{
    prefix: "uplink"
  }

config :uplink, :environment, :test
config :lexdee, :environment, :test

config :uplink, Oban, plugins: false, queues: false

config :uplink, Uplink.Secret, "secretsomethingsixteen"

config :uplink, Uplink.Clients.Instellar, endpoint: "http://localhost/uplink"

# config :plug, :validate_header_keys_during_test, false
# Print only warnings and errors during test
config :logger, level: :warn
