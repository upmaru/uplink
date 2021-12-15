use Mix.Config

config :uplink, Uplink.Repo,
  username: System.get_env("UPLINK_DB_USERNAME"),
  password: System.get_env("UPLINK_DB_PASSWORD"),
  hostname: System.get_env("UPLINK_DB_HOST") || "localhost",
  database: "uplink_test",
  queue_target: 50_000,
  queue_interval: 50_000,
  pool: Ecto.Adapters.SQL.Sandbox

config :uplink, Uplink.Secret, "secret"

# config :plug, :validate_header_keys_during_test, false
# Print only warnings and errors during test
config :logger, level: :warn
