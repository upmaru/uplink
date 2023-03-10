defmodule Uplink.Clients.Caddy.Config.Reload do
  use Oban.Worker, queue: :caddy, max_attempts: 1

  alias Uplink.Repo
  alias Uplink.Cache

  alias Uplink.Packages
  alias Uplink.Packages.Install

  alias Uplink.Clients.Caddy

  import Ecto.Query, only: [preload: 2]

  def perform(%Oban.Job{args: %{"install_id" => install_id}}) do
    %Install{} =
      install =
      Install
      |> preload([:deployment])
      |> Repo.get(install_id)

    install
    |> Packages.install_cache_key()
    |> Cache.delete()

    (Node.list() ++ [Node.self()])
    |> Enum.each(fn node ->
      Task.Supervisor.async_nolink({Uplink.TaskSupervisor, node}, fn ->
        Caddy.build_new_config()
        |> Caddy.load_config()
      end)
    end)
  end
end
