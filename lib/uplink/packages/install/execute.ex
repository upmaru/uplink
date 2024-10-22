defmodule Uplink.Packages.Install.Execute do
  use Oban.Worker, queue: :install, max_attempts: 1

  alias Uplink.Repo
  alias Uplink.Cache
  alias Uplink.Instances

  alias Uplink.Clients.LXD
  alias Uplink.Clients.Instellar

  alias Uplink.Members.Actor

  alias Uplink.Packages
  alias Uplink.Packages.Install
  alias Uplink.Packages.Metadata

  alias Uplink.Packages.Instance.Bootstrap
  alias Uplink.Packages.Instance.Upgrade

  import Ecto.Query,
    only: [where: 3, preload: 2]

  @state ~s(executing)

  @task_supervisor Application.compile_env(:uplink, :task_supervisor) ||
                     Task.Supervisor

  @transition_parameters %{
    "from" => "uplink",
    "trigger" => false
  }

  def perform(%Oban.Job{
        args: %{"install_id" => install_id, "actor_id" => actor_id}
      }) do
    %Actor{} = actor = Repo.get(Actor, actor_id)

    %Install{} =
      install =
      Install
      |> where(
        [i],
        i.current_state == ^@state
      )
      |> preload([:deployment])
      |> Repo.get(install_id)

    install
    |> Packages.build_install_state(actor)
    |> validate_and_execute_instances()
  end

  defp validate_and_execute_instances(
         %{
           metadata: %Metadata{instances: instances} = metadata
         } = state
       ) do
    client = LXD.client()

    project = Packages.get_project_name(client, metadata)

    existing_instances =
      LXD.list_instances(project: project)
      |> Enum.filter(&only_uplink_instance/1)

    Cache.put_new({:install, state.install.id, "completed"}, [],
      ttl: :timer.hours(24)
    )

    Cache.put_new({:install, state.install.id, "executing"}, [],
      ttl: :timer.hours(24)
    )

    jobs =
      instances
      |> Enum.map(&choose_execution_path(&1, existing_instances, state))

    {:ok, jobs}
  end

  defp only_uplink_instance(instance) do
    config = instance.expanded_config
    managed_by = Map.get(config, "user.managed_by")
    managed_by == "uplink"
  end

  defp choose_execution_path(instance, existing_instances, state) do
    existing_instances_name = Enum.map(existing_instances, & &1.name)

    event_name =
      if instance.slug in existing_instances_name, do: "upgrade", else: "boot"

    @task_supervisor.async_nolink(Uplink.TaskSupervisor, fn ->
      Instellar.transition_instance(instance.slug, state.install, event_name,
        comment: "[Uplink.Packages.Install.Execute]",
        parameters: @transition_parameters
      )
    end)

    Instances.mark("executing", state.install.id, instance.slug)

    case event_name do
      "upgrade" ->
        existing_instance =
          Enum.find(existing_instances, &(&1.name == instance.slug))

        %{
          "instance" => %{
            "slug" => instance.slug,
            "node" => %{
              "slug" => existing_instance.location
            }
          },
          "install_id" => state.install.id,
          "actor_id" => state.actor.id
        }
        |> Upgrade.new()
        |> Oban.insert()

      "boot" ->
        Bootstrap.new(%{
          "instance" => %{
            "slug" => instance.slug
          },
          "install_id" => state.install.id,
          "actor_id" => state.actor.id
        })
        |> Oban.insert()
    end
  end
end
