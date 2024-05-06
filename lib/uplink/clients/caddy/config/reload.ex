defmodule Uplink.Clients.Caddy.Config.Reload do
  use Oban.Worker, queue: :caddy, max_attempts: 1

  @moduledoc """
  Reloads configuration for caddy on all nodes
  """

  alias Uplink.Repo
  alias Uplink.Cache

  alias Uplink.Packages
  alias Uplink.Packages.Install

  alias Uplink.Clients.Caddy

  import Ecto.Query, only: [preload: 2]

  require Logger

  @task_supervisor Application.compile_env(:uplink, :task_supervisor) ||
                     Task.Supervisor

  def perform(%Oban.Job{args: %{"install_id" => install_id}}) do
    %Install{} =
      install =
      Install
      |> preload([:deployment])
      |> Repo.get(install_id)

    install
    |> Packages.install_cache_key()
    |> Cache.delete()

    [Node.self() | Node.list()]
    |> Enum.each(fn node ->
      Logger.info("[Caddy.Config.Reload] running on #{node}...")

      @task_supervisor.async_nolink({Uplink.TaskSupervisor, node}, fn ->
        Caddy.build_new_config()
        |> Caddy.load_config()
      end)
    end)

    {:ok, :reloaded}
  end
end
