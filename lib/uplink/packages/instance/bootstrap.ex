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
  alias Uplink.Packages.Instance.Placement

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
          "instance" => instance_params,
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

    state = Packages.build_install_state(install, actor)

    state
    |> handle_placement(instance_params)
    |> case do
      %{client: _, lxd_project_name: _, placement: _} = updated_state ->
        handle_provisioning(updated_state, instance_params)

      error ->
        handle_error(state, error, instance_params)
    end
  end

  defp handle_placement(
         %{
           install: install,
           metadata:
             %{orchestration: %{placement: placement_strategy}} = metadata
         } = state,
         %{"slug" => instance_name}
       ) do
    placement_name = Placement.name(instance_name)

    Cache.transaction([keys: [{:available_nodes, placement_name}]], fn ->
      with {:ok, %Placement{node: node} = placement} <-
             Placement.find(instance_name, placement_strategy),
           %Member{architecture: architecture} <-
             LXD.list_cluster_members()
             |> Enum.find(fn member ->
               member.server_name == node
             end) do
        client = LXD.client()

        profile_name = Packages.profile_name(metadata)

        size_profile_name = Packages.get_size_profile(metadata)

        lxd_project_name = Packages.get_or_create_project_name(client, metadata)

        image_server = get_image_server()

        profiles = [profile_name, "default"]

        profiles =
          if size_profile_name do
            [size_profile_name | profiles]
          else
            profiles
          end

        lxd_instance =
          Map.merge(@default_params, %{
            "name" => instance_name,
            "architecture" => architecture,
            "profiles" => profiles,
            "source" => %{
              "type" => "image",
              "mode" => "pull",
              "protocol" => "simplestreams",
              "server" => image_server,
              "alias" => install.deployment.stack
            }
          })

        client
        |> Formation.lxd_create(node, lxd_instance, project: lxd_project_name)
        |> case do
          %Tesla.Client{} = client ->
            transition_parameters =
              Map.put(
                @transition_parameters,
                "node",
                node
              )

            Uplink.TaskSupervisor
            |> @task_supervisor.async_nolink(
              fn ->
                Instellar.transition_instance(instance_name, install, "boot",
                  comment:
                    "[Uplink.Packages.Instance.Bootstrap] Starting bootstrap with #{placement_strategy} placement...",
                  parameters: transition_parameters
                )
              end,
              shutdown: 30_000
            )

            Cache.get_and_update(
              {:available_nodes, placement_name},
              fn current_value ->
                if is_list(current_value) do
                  {current_value, current_value -- [node]}
                else
                  {current_value, []}
                end
              end
            )

            state
            |> Map.put(:client, client)
            |> Map.put(:lxd_project_name, lxd_project_name)
            |> Map.put(:placement, placement)

          error ->
            error
        end
      end
    end)
  end

  defp handle_provisioning(
         %{
           client: client,
           metadata: %{channel: channel} = metadata,
           install: install,
           actor: actor,
           lxd_project_name: lxd_project_name,
           placement: placement
         },
         %{"slug" => instance_name} = instance_params
       ) do
    package_distribution_url = Packages.distribution_url(metadata)
    package = channel.package

    formation_instance_params = %{
      "project" => lxd_project_name,
      "slug" => instance_name,
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
    |> Formation.lxd_start(instance_name, project: lxd_project_name)
    |> Formation.setup_lxd_instance(formation_instance)
    |> case do
      {:ok, _message} ->
        %{
          "instance" => %{
            "slug" => instance_name,
            "node" => %{
              "slug" => placement.node
            }
          },
          "install_id" => install.id,
          "actor_id" => actor.id
        }
        |> Instance.Install.new(schedule_in: 10)
        |> Oban.insert()

      {:error, error} ->
        transition_parameters =
          Map.put(
            @transition_parameters,
            "node",
            placement.node
          )

        Uplink.TaskSupervisor
        |> @task_supervisor.async_nolink(
          fn ->
            Instellar.transition_instance(instance_name, install, "fail",
              comment: "[Uplink.Packages.Instance.Bootstrap] #{inspect(error)}",
              parameters: transition_parameters
            )
          end,
          shutdown: 30_000
        )

        instance_params = Map.put(instance_params, "current_state", "failing")

        %{
          "instance" => instance_params,
          "install_id" => install.id,
          "actor_id" => actor.id
        }
        |> Cleanup.new()
        |> Oban.insert()
    end
  end

  defp handle_error(%{install: install, actor: _actor}, error, %{
         "slug" => instance_name
       }) do
    Instellar.transition_instance(instance_name, install, "fail",
      comment:
        "[Uplink.Packages.Instance.Bootstrap] #{instance_name} #{inspect(error)}",
      parameters: @transition_parameters
    )
  end

  defp get_image_server do
    case Uplink.Clients.Instellar.get_self() do
      %{"uplink" => %{"image_server" => image_server}} ->
        image_server

      _ ->
        polar_config = Application.get_env(:uplink, :polar)
        Keyword.fetch!(polar_config, :endpoint)
    end
  end
end
