defmodule Uplink.Packages.Instance.Install do
  use Oban.Worker, queue: :instance, max_attempts: 3

  alias Uplink.Repo
  alias Uplink.Instances

  alias Uplink.Clients.LXD
  alias Uplink.Clients.Caddy
  alias Uplink.Clients.Instellar

  alias Uplink.Packages
  alias Uplink.Packages.Install
  alias Uplink.Packages.Instance.Finalize
  alias Uplink.Packages.Instance.Cleanup

  alias Uplink.Members.Actor

  import Ecto.Query, only: [preload: 2]

  @transition_parameters %{
    "from" => "uplink",
    "trigger" => false
  }

  @task_supervisor Application.compile_env(:uplink, :task_supervisor) ||
                     Task.Supervisor

  def perform(
        %Oban.Job{
          args: %{
            "instance" =>
              %{
                "slug" => name
              } = instance_params,
            "install_id" => install_id,
            "actor_id" => actor_id
          }
        } = job
      ) do
    %Actor{} = actor = Repo.get(Actor, actor_id)

    %Install{} =
      install =
      Install
      |> preload([:deployment])
      |> Repo.get(install_id)

    %{metadata: metadata} = Packages.build_install_state(install, actor)
    client = LXD.client()

    project_name = Packages.get_project_name(client, metadata)
    package_distribution_url = Packages.distribution_url(metadata)
    package = metadata.channel.package

    formation_instance_params = %{
      "project" => project_name,
      "slug" => name,
      "repositories" => [
        %{
          "url" => package_distribution_url,
          "public_key_name" => Packages.public_key_name(metadata),
          "public_key" => package.credential.public_key
        }
      ],
      "packages" => [
        %{
          "slug" => package.slug
        }
      ]
    }

    formation_instance = Formation.new_lxd_instance(formation_instance_params)

    node = Map.get(instance_params, "node", %{})

    transition_parameters =
      Map.put(@transition_parameters, "node", node["slug"])

    Uplink.TaskSupervisor
    |> @task_supervisor.async_nolink(
      fn ->
        Instellar.transition_instance(name, install, "boot",
          comment:
            "[Uplink.Packages.Instance.Install] Installing #{package.slug}...",
          parameters: transition_parameters
        )
      end,
      shutdown: 30_000
    )

    client
    |> Formation.add_package_and_restart_lxd_instance(formation_instance)
    |> case do
      {:ok, add_package_output} ->
        Instances.mark("completed", install_id, name)

        Caddy.schedule_config_reload(install)

        Packages.maybe_mark_install_complete(install, actor)

        %{
          "instance" => instance_params,
          "comment" => add_package_output,
          "install_id" => install_id,
          "actor_id" => actor_id
        }
        |> Finalize.new()
        |> Oban.insert()

      {:error, %{"error" => "Instance is not running"}} ->
        {:snooze, 5}

      {:error, error} ->
        if job.attempt == job.max_attempts do
          error =
            cond do
              is_binary(error) -> error
              true -> inspect(error)
            end

          Uplink.TaskSupervisor
          |> @task_supervisor.async_nolink(
            fn ->
              Instellar.transition_instance(
                formation_instance.slug,
                install,
                "fail",
                comment: "[Uplink.Packages.Instance.Install] #{error}",
                parameters: @transition_parameters
              )
            end,
            shutdown: 30_000
          )

          instance_params = Map.put(instance_params, "current_state", "failing")

          %{
            "instance" => instance_params,
            "comment" => error,
            "install_id" => install_id,
            "actor_id" => actor_id
          }
          |> Cleanup.new()
          |> Oban.insert()
        end

        {:error, error}
    end
  end
end
