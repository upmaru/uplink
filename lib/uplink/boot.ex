defmodule Uplink.Boot do
  use Task

  alias Uplink.Clients.Instellar

  require Logger

  def start_link(args) do
    Task.start_link(__MODULE__, :run, [args])
  end

  def run(_args) do
    Logger.info("[Boot] Establishing uplink...")

    Instellar.Register.perform()
  end
end
