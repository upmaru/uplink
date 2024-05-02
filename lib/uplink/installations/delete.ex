defmodule Uplink.Installations.Delete do
  use Oban.Worker, queue: :installations, max_attempts: 1

  alias Uplink.Repo
  alias Uplink.Packages.Install

  import Ecto.Query, only: [where: 3]

  require Logger

  @task_supervisor Application.compile_env(:uplink, :task_supervisor) ||
                     Task.Supervisor

  def perform(%Job{args: %{"instellar_installation_id" => instellar_installation_id}}) do
    Install
    |> where([i], i.instellar_installation_id == ^instellar_installation_id)
    |> Repo.update_all(set: [
      instellar_installation_state: "deleted", 
      updated_at: DateTime.utc_now()
    ])

    [Node.self() | Node.list()]
    |> Enum.each(fn node ->
      Logger.info("[Caddy.Config.Reload] running on #{node}...")

      @task_supervisor.async_nolink({Uplink.TaskSupervisor, node}, fn ->
        Caddy.build_new_config()
        |> Caddy.load_config()
      end)
    end)

    {:ok, :deleted}
  end
end