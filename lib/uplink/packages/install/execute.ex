defmodule Uplink.Packages.Install.Execute do
  use Oban.Worker, queue: :execute_install, max_attempts: 1

  alias Uplink.{
    Clients,
    Members,
    Packages,
    Repo
  }

  alias Members.Actor

  alias Packages.{
    Install,
    Instance,
    Metadata
  }

  alias Clients.{
    LXD,
    Instellar
  }

  import Ecto.Query,
    only: [where: 3, preload: 2]

  @state ~s(executing)

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
           metadata: %Metadata{instances: instances}
         } = state
       ) do
    existing_instances_name =
      LXD.list_instances()
      |> Enum.filter(&only_uplink_instance/1)
      |> Enum.map(fn instance ->
        instance.name
      end)

    jobs =
      instances
      |> Enum.map(&choose_execution_path(&1, existing_instances_name, state))

    {:ok, jobs}
  end

  defp only_uplink_instance(instance) do
    config = instance.expanded_config
    managed_by = Map.get(config, "user.managed_by")
    managed_by == "uplink"
  end

  alias Instance.{
    Bootstrap
  }

  defp choose_execution_path(instance, existing_instances, state) do
    job_params = %{
      instance: %{
        slug: instance.slug,
        node: %{
          slug: instance.node.slug
        }
      },
      install_id: state.install.id,
      actor_id: state.actor.id
    }

    if instance.slug in existing_instances do
      Instellar.transition_instance(instance.slug, state.install, "upgrade",
        comment: "[Uplink.Packages.Install.Execute]"
      )
    else
      job_params
      |> Bootstrap.new()
      |> Oban.insert()
    end
  end
end
