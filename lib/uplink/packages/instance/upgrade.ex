defmodule Uplink.Packages.Instance.Upgrade do
  use Oban.Worker,
    queue: :instance,
    max_attempts: 1

  alias Uplink.{
    Members,
    Clients,
    Packages,
    Repo
  }

  alias Members.Actor

  alias Packages.{
    Install,
    Instance
  }

  alias Clients.{
    LXD,
    Instellar
  }

  import Ecto.Query, only: [limit: 2, where: 3, preload: 2, order_by: 2]

  def perform(
        %Oban.Job{
          args: %{
            "instance" => %{
              "slug" => name
            },
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

    with %{metadata: %{channel: channel} = metadata} <-
           Packages.build_install_state(install, actor),
         {:ok, _transition} <-
           Instellar.transition_instance(name, install, "upgrade",
             comment: "[Uplink.Packages.Instance.Upgrade]"
           ) do
      client = LXD.client()

      project_name = Packages.get_project_name(client, metadata)

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
      |> validate_stack(install)
      |> handle_upgrade(job, actor)
    end
  end

  defp validate_stack(
         formation_instance,
         %Install{
           id: install_id,
           instellar_installation_id: instellar_installation_id,
           deployment: incoming_deployment
         } = install
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
          {:upgrade, formation_instance, install}
        else
          {:deactivate_and_bootstrap, formation_instance, install}
        end

      nil ->
        {:upgrade, formation_instance, install}
    end
  end

  defp handle_upgrade(
         {:upgrade, formation_instance, install},
         %Job{} = job,
         actor
       ) do
    LXD.client()
    |> Formation.lxd_upgrade_alpine_package(formation_instance)
    |> case do
      {:ok, upgrade_package_output} ->
        Instellar.transition_instance(
          formation_instance.slug,
          install,
          "complete",
          comment: upgrade_package_output
        )

        maybe_mark_install_complete(install, actor)

      {:error, %{"err" => "Failed to retrieve PID of executing child process"}} ->
        Instellar.transition_instance(
          formation_instance.slug,
          install,
          "revert",
          comment:
            "Reverting please restart the underlying node and try upgrading again."
        )

      {:error, error} ->
        handle_error(error, job)
    end
  end

  defp handle_upgrade(
         {:deactivate_and_bootstrap, _formation_instance, _install},
         %Job{args: args},
         _actor
       ),
       do: deactivate_and_boot(args)

  defp handle_error(comment, %Job{attempt: _attempt, args: args}),
    do: deactivate_and_boot(args, comment: comment)

  defp deactivate_and_boot(args, options \\ []) do
    args
    |> Map.merge(%{
      "mode" => "deactivate_and_boot",
      "comment" => Keyword.get(options, :comment)
    })
    |> Instance.Cleanup.new()
    |> Oban.insert()
  end

  defp maybe_mark_install_complete(install, actor) do
    with {:ok, %{"current_state" => "synced"}} <-
           Instellar.deployment_metadata(install),
         {:ok, transition} <-
           Packages.transition_install_with(install, actor, "complete") do
      {:ok, transition}
    else
      _ -> :ok
    end
  end
end
