defmodule Uplink.Clients.Caddy.Hydrate do
  use Oban.Worker,
    queue: :caddy,
    max_attempts: 2

  alias Uplink.Clients.Caddy

  def perform(%Job{} = _job) do
    Caddy.build_new_config()
    |> Caddy.load_config()
  end
end
