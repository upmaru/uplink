defmodule Uplink.Repo do
  use Ecto.Repo,
    otp_app: :uplink,
    adapter: Ecto.Adapters.Postgres
end
