defmodule Uplink.Packages.Instance.Restart do
  use Oban.Worker, queue: :instance, max_attempts: 3

  alias Uplink.Repo
  alias Uplink.Packages

  alias Uplink.Clients.LXD
  alias Uplink.Clients.Instellar

  alias Uplink.Members.Actor
  alias Uplink.Packages.Install

  @transition_parameters %{
    "from" => "uplink",
    "trigger" => false
  }

  @task_supervisor Application.compile_env(:uplink, :task_supervisor) ||
                     Task.Supervisor

  def perform(%Job{
        args: %{
          "instance" => %{"slug" => name},
          "install_id" => install_id,
          "actor_id" => actor_id
        }
      }) do
    %Actor{} = actor = Repo.get(Actor, actor_id)

    client = LXD.client()

    %Install{} =
      install =
      Install
      |> Repo.get(install_id)
      |> Repo.preload([:deployment])

    %{metadata: metadata} = Packages.build_install_state(install, actor)

    project_name = Packages.get_project_name(client, metadata)

    with {:ok, _} <- Formation.lxd_stop(client, name, project: project_name),
         %Tesla.Client{} <-
           Formation.lxd_start(client, name, project: project_name) do
      Uplink.TaskSupervisor
      |> @task_supervisor.async_nolink(
        fn ->
          Instellar.transition_instance(name, install, "complete",
            comment:
              "[Uplink.Packages.Instance.Restart] Instance #{name} restarted.",
            parameters: @transition_parameters
          )
        end,
        shutdown: 30_000
      )
    end
    |> handle_response(name, install)
  end

  defp handle_response({:ok, %{"status_code" => 400}}, name, install),
    do: handle_error(name, install)

  defp handle_response({:error, :instance_stop_failed}, name, install),
    do: handle_error(name, install, "instance stop failed")

  defp handle_response({:error, %{body: %{"error" => error}}}, name, install),
    do: handle_error(name, install, error)

  defp handle_response({:error, error}, name, install),
    do: handle_error(name, install, error)

  defp handle_response(_, _name, _install),
    do: {:ok, :restarted}

  defp handle_error(name, install, message \\ nil) do
    comment =
      if message do
        "[Uplink.Packages.Instance.Restart] Instance #{name} stuck."
      else
        "[Uplink.Packages.Instance.Restart] #{message}"
      end

    Uplink.TaskSupervisor
    |> @task_supervisor.async_nolink(
      fn ->
        Instellar.transition_instance(name, install, "stuck",
          comment: comment,
          parameters: @transition_parameters
        )
      end,
      shutdown: 30_000
    )
  end
end
