defmodule Uplink.Packages.Instance.Cleanup do
  use Oban.Worker, queue: :instance, max_attempts: 3

  alias Uplink.{
    Clients,
    Packages,
    Members,
    Repo
  }

  alias Members.Actor

  alias Clients.{
    LXD,
    Caddy,
    Instellar
  }

  alias Packages.{
    Install,
    Instance
  }

  alias Instance.Bootstrap

  @transition_parameters %{
    "from" => "uplink",
    "trigger" => false
  }

  @cleanup_mappings %{
    "failing" => "fail",
    "deactivating" => "off"
  }

  @task_supervisor Application.compile_env(:uplink, :task_supervisor) ||
                     Task.Supervisor

  def perform(%Oban.Job{
        args:
          %{
            "instance" => %{
              "slug" => name
            },
            "install_id" => install_id,
            "actor_id" => actor_id
          } = args
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

    lxd = Formation.Lxd.impl()

    with {:ok, _} <-
           lxd.get_instance(client, name, query: [project: project_name]),
         {:ok, _} <- Formation.lxd_stop(client, name, project: project_name),
         {:ok, _} <- Formation.lxd_delete(client, name, project: project_name) do
      finalize(name, install, Map.get(args, "mode", "cleanup"), args)
    else
      {:error, %{"error_code" => 404}} ->
        finalize(name, install, "cleanup", args)

      error ->
        error
    end
  end

  defp finalize(
         name,
         install,
         "cleanup",
         %{
           "instance" => %{"current_state" => current_state}
         } = args
       ) do
    Caddy.schedule_config_reload(install)

    Uplink.TaskSupervisor
    |> @task_supervisor.async_nolink(
      fn ->
        event_name = Map.get(@cleanup_mappings, current_state, "off")
        comment = Map.get(args, "comment", "no comment")

        Instellar.transition_instance(name, install, event_name,
          comment:
            "[Uplink.Packages.Instance.Cleanup] #{parse_comment(comment)}"
        )
      end,
      shutdown: 30_000
    )

    {:ok, :cleaned}
  end

  defp finalize(name, install, "deactivate_and_boot", args) do
    Uplink.TaskSupervisor
    |> @task_supervisor.async_nolink(
      fn ->
        comment = Map.get(args, "comment", "no comment")

        Instellar.transition_instance(name, install, "deactivate",
          comment:
            "[Uplink.Packages.Instance.Cleanup] #{parse_comment(comment)}",
          parameters: @transition_parameters
        )
      end,
      shutdown: 30_000
    )

    args
    |> Bootstrap.new()
    |> Oban.insert()
  end

  defp parse_comment(comment) when is_binary(comment), do: comment

  defp parse_comment(comment), do: inspect(comment)
end
