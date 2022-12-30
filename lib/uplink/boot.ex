defmodule Uplink.Boot do
  use Task

  alias Uplink.{
    Packages
  }

  alias Uplink.Clients.{
    Instellar,
    Caddy
  }

  require Logger

  def start_link(args) do
    Task.start_link(__MODULE__, :run, [args])
  end

  def run(_args) do
    Logger.info("[Boot] Establishing uplink...")

    Instellar.Register.perform()

    Logger.info("[Boot] Hydrating caddy...")

    Caddy.build_new_config()
    |> Caddy.load_config()

    Logger.info("[Boot] Caddy hydrated...")

    Packages.Archive.Hydrate.Schedule.new(%{})
    |> Oban.insert()
  end
end
