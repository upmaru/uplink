defmodule Uplink.Packages.Instance.Upgrade do
  alias Ecto.Schema.Metadata

  use Oban.Worker,
    queue: :instance,
    max_attempts: 1

  alias Uplink.Repo
  alias Uplink.Cache

  alias Uplink.Packages
  alias Uplink.Packages.Install
  alias Uplink.Packages.Instance
  alias Uplink.Packages.Metadata

  alias Uplink.Members.Actor

  alias Uplink.Clients.LXD
  alias Uplink.Clients.Instellar
  alias Uplink.Clients.Caddy

  import Ecto.Query, only: [limit: 2, where: 3, preload: 2, order_by: 2]

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
    Cache.put_new({:install, install_id, "completed"}, [], ttl: :timer.hours(24))

    Cache.put_new({:install, install_id, "executing"}, [], ttl: :timer.hours(24))

    %Actor{} = actor = Repo.get(Actor, actor_id)

    %Install{} =
      install =
      Install
      |> preload([:deployment])
      |> Repo.get(install_id)

    node = Map.get(instance_params, "node", %{})

    transition_parameters =
      Map.put(@transition_parameters, "node", node["slug"])

    %{metadata: %{channel: channel} = metadata} =
      Packages.build_install_state(install, actor)

    client = LXD.client()
    project_name = Packages.get_project_name(client, metadata)

    @task_supervisor.async_nolink(Uplink.TaskSupervisor, fn ->
      Instellar.transition_instance(name, install, "upgrade",
        comment:
          "[Uplink.Packages.Instance.Upgrade] Upgrading #{channel.package.slug} on #{name}...",
        parameters: transition_parameters
      )
    end)

    Formation.new_lxd_instance(%{
      project: project_name,
      slug: name,
      repositories: [],
      packages: [
        %{
          slug: channel.package.slug
        }
      ]
    })
    |> validate_stack(install, metadata)
    |> handle_upgrade(job, actor)
  end

  defp validate_stack(
         formation_instance,
         %Install{
           id: install_id,
           instellar_installation_id: instellar_installation_id,
           deployment: incoming_deployment
         } = install,
         metadata
       ) do
    Install
    |> where(
      [i],
      i.id != ^install_id and
        i.instellar_installation_id == ^instellar_installation_id
    )
    |> order_by(desc: :inserted_at)
    |> preload([:deployment])
    |> limit(1)
    |> Repo.one()
    |> case do
      %Install{deployment: %{stack: previous_stack}} ->
        if previous_stack == incoming_deployment.stack do
          {:upgrade, formation_instance, install, metadata}
        else
          {:deactivate_and_bootstrap, formation_instance, install, metadata}
        end

      nil ->
        {:upgrade, formation_instance, install, metadata}
    end
  end

  defp handle_upgrade(
         {:upgrade, formation_instance, install, metadata},
         %Job{args: %{"instance" => instance_params}} = job,
         actor
       ) do
    node = Map.get(instance_params, "node", %{})

    transition_parameters =
      Map.put(@transition_parameters, "node", node["slug"])

    LXD.client()
    |> handle_update_config(formation_instance, metadata)
    |> Formation.lxd_upgrade_alpine_package(formation_instance)
    |> case do
      {:ok, upgrade_package_output} ->
        Cache.transaction([keys: [{:install, install.id, "completed"}]], fn ->
          Cache.get_and_update(
            {:install, install.id, "completed"},
            fn current_value ->
              completed_instances =
                if current_value,
                  do: current_value ++ [formation_instance.slug],
                  else: [formation_instance.slug]

              {current_value, Enum.uniq(completed_instances)}
            end
          )
        end)

        Caddy.schedule_config_reload(install)

        Packages.maybe_mark_install_complete(install, actor)

        %{
          "instance" => instance_params,
          "comment" => upgrade_package_output,
          "install_id" => install.id,
          "actor_id" => actor.id
        }
        |> Instance.Finalize.new()
        |> Oban.insert()

      {:error, %{"err" => "Failed to retrieve PID of executing child process"}} ->
        Uplink.TaskSupervisor
        |> @task_supervisor.async_nolink(
          fn ->
            Instellar.transition_instance(
              formation_instance.slug,
              install,
              "revert",
              comment:
                "Reverting please restart the underlying node and try upgrading again.",
              parameters: transition_parameters
            )
          end,
          shutdown: 30_000
        )

        {:ok, :reverted}

      {:error, error} ->
        handle_error(error, job, metadata)
    end
  end

  defp handle_upgrade(
         {:deactivate_and_bootstrap, _formation_instance, _install, _metadata},
         %Job{args: args},
         _actor
       ),
       do:
         deactivate_and_boot(args,
           comment: "stack changed deactivating and bootstrapping"
         )

  defp handle_error(comment, %Job{attempt: _attempt, args: args}, metadata) do
    case metadata.orchestration do
      %Metadata.Orchestration{on_fail: "restart"} ->
        restart(args, comment: comment)

      %Metadata.Orchestration{on_fail: "cleanup"} ->
        deactivate_and_boot(args, comment: comment)
    end
  end

  defp restart(args, options) do
    args
    |> Map.merge(%{
      "comment" => Keyword.get(options, :comment)
    })
    |> Instance.Restart.new()
    |> Oban.insert()
  end

  defp deactivate_and_boot(args, options) do
    args
    |> Map.merge(%{
      "mode" => "deactivate_and_boot",
      "comment" => Keyword.get(options, :comment)
    })
    |> Instance.Cleanup.new()
    |> Oban.insert()
  end

  defp handle_update_config(client, instance, metadata) do
    profile_name = Packages.profile_name(metadata)
    size_profile_name = Packages.get_size_profile(metadata)

    profiles = [profile_name, "default"]

    profiles =
      if size_profile_name do
        [size_profile_name | profiles]
      else
        profiles
      end

    params = %{
      "profiles" => profiles
    }

    client
    |> Lexdee.update_instance(instance.slug, params,
      query: [project: instance.project]
    )
    |> case do
      {:ok, _message} ->
        client

      {:error, error} ->
        raise "Failed to update instance config: #{inspect(error)}"
    end
  end
end
