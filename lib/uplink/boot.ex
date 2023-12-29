defmodule Uplink.Boot do
  use Task

  alias Uplink.{
    Repo,
    Packages
  }

  alias Uplink.Clients.Instellar

  import Ecto.Query, only: [from: 2]

  require Logger

  @task_supervisor Application.compile_env(:uplink, :task_supervisor) ||
                     Task.Supervisor

  def start_link(args) do
    Task.start_link(__MODULE__, :run, [args])
  end

  def run(_args) do
    Logger.info("[Boot] Establishing uplink...")

    Uplink.TaskSupervisor
    |> @task_supervisor.async_nolink(
      fn ->
        Instellar.register()
      end,
      shutdown: 30_000
    )

    from(
      i in Packages.Install,
      limit: 10
    )
    |> Repo.all()
    |> case do
      [] ->
        Instellar.restore()

      _ ->
        Logger.info("[Boot] Hydrating archive...")

        Packages.Archive.Hydrate.Schedule.new(%{})
        |> Oban.insert()
    end
  end
end
