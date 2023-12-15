defmodule Uplink.Packages.Instance.Bootstrap do
  use Oban.Worker,
    queue: :instance,
    max_attempts: 1

  alias Uplink.Repo
  alias Uplink.Cache
  alias Uplink.Members.Actor

  alias Uplink.Packages
  alias Uplink.Packages.Install
  alias Uplink.Packages.Instance
  alias Uplink.Packages.Instance.Cleanup

  alias Uplink.Clients.Instellar

  alias Uplink.Clients.LXD
  alias Uplink.Clients.LXD.Cluster.Member

  @transition_parameters %{
    "from" => "uplink",
    "trigger" => false
  }

  @default_params %{
    "ephemeral" => false,
    "type" => "container"
  }

  @task_supervisor Application.compile_env(:uplink, :task_supervisor) ||
                     Task.Supervisor

  import Ecto.Query, only: [preload: 2]

  def perform(%Oban.Job{
        args: %{
          "instance" =>
            %{
              "slug" => name
            } = instance_params,
          "install_id" => install_id,
          "actor_id" => actor_id
        }
      }) do
    Cache.put_new({:install, install_id, "completed"}, [], ttl: :timer.hours(24))

    Cache.put_new({:install, install_id, "executing"}, [], ttl: :timer.hours(24))

    %Actor{} = actor = Repo.get(Actor, actor_id)

    %Install{} =
      install =
      Install
      |> preload([:deployment])
      |> Repo.get(install_id)

    frequency =
      LXD.list_instances()
      |> Enum.frequencies_by(fn instance ->
        instance.location
      end)

    selected_member =
      LXD.list_cluster_members()
      |> Enum.min_by(fn m -> frequency[m.server_name] || 0 end)

    transition_parameters =
      Map.put(@transition_parameters, "node", selected_member.server_name)

    Uplink.TaskSupervisor
    |> @task_supervisor.async_nolink(
      fn ->
        Instellar.transition_instance(name, install, "boot",
          comment: "[Uplink.Packages.Instance.Bootstrap] Starting bootstrap...",
          parameters: transition_parameters
        )
      end,
      shutdown: 30_000
    )

    with %{metadata: %{channel: channel} = metadata} <-
           Packages.build_install_state(install, actor),
         members when is_list(members) <- LXD.list_cluster_members(),
         %Member{architecture: architecture} <-
           members
           |> Enum.find(fn member ->
             member.server_name == selected_member.server_name
           end) do
      profile_name = Packages.profile_name(metadata)
      package = channel.package

      lxd_instance_params =
        Map.merge(@default_params, %{
          "name" => name,
          "architecture" => architecture,
          "profiles" => [
            profile_name,
            "default"
          ],
          "source" => %{
            "type" => "image",
            "mode" => "pull",
            "protocol" => "simplestreams",
            "server" => "https://images.linuxcontainers.org",
            "alias" => install.deployment.stack
          }
        })

      package_distribution_url = Packages.distribution_url(metadata)

      client = LXD.client()

      project_name = Packages.get_or_create_project_name(client, metadata)

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

      client
      |> Formation.lxd_create(selected_member.server_name, lxd_instance_params,
        project: project_name
      )
      |> Formation.lxd_start(name, project: project_name)
      |> Formation.setup_lxd_instance(formation_instance)
      |> case do
        {:ok, _message} ->
          %{
            "instance" => %{
              "slug" => name,
              "node" => %{
                "slug" => selected_member.server_name
              }
            },
            "install_id" => install.id,
            "actor_id" => actor_id
          }
          |> Instance.Install.new()
          |> Oban.insert()

        {:error, error} ->
          Uplink.TaskSupervisor
          |> @task_supervisor.async_nolink(
            fn ->
              Instellar.transition_instance(name, install, "fail",
                comment:
                  "[Uplink.Packages.Instance.Bootstrap] #{inspect(error)}",
                parameters: transition_parameters
              )
            end,
            shutdown: 30_000
          )

          instance_params = Map.put(instance_params, "current_state", "failing")

          %{
            "instance" => instance_params,
            "install_id" => install_id,
            "actor_id" => actor_id
          }
          |> Cleanup.new()
          |> Oban.insert()
      end
    else
      {:error, error} ->
        Packages.transition_install_with(install, actor, "fail",
          comment: "#{inspect(error)}"
        )

      nil ->
        Packages.transition_install_with(install, actor, "fail",
          comment: "cluster member not found"
        )
    end
  end
end
