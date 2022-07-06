defmodule Uplink.Packages.Instance.Upgrade do
  use Oban.Worker, queue: :process_instance, max_attempts: 1

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

  import Ecto.Query, only: [where: 3, preload: 2, order_by: 2]

  @install_state ~s(executing)

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

    %Install{} =
      install =
      Install
      |> where(
        [i],
        i.current_state == ^@install_state
      )
      |> preload([:deployment])
      |> Repo.get(install_id)

    with %{metadata: %{channel: channel} = metadata} <-
           Packages.build_install_state(install, actor),
         {:ok, _transition} <-
           Instellar.transition_instance(name, install, "upgrade",
             comment: "[Uplink.Packages.Instance.Upgrade]"
           ) do
      Formation.Lxd.Instance.new(%{
        slug: name,
        package: %{
          slug: channel.package.slug
        },
        url: nil,
        credential: %{"public_key" => nil}
      })
      |> validate_stack(install)
      |> handle_upgrade(install, args)
    end
  end

  defp validate_stack(formation_instance, %Install{
         id: install_id,
         deployment: current_deployment
       }) do
    previous_install =
      Install
      |> where(
        [i],
        i.id != ^install_id and
          i.current_state == "completed"
      )
      |> order_by(desc: :inserted_at)
      |> preload([:deployment])
      |> Repo.one()

    if previous_install.deployment.stack == current_deployment.stack do
      {:upgrade, formation_instance}
    else
      {:deactivate_and_bootstrap, formation_instance}
    end
  end

  defp handle_upgrade({:upgrade, formation_instance}, install) do
    LXD.client()
    |> Formation.Lxd.Alpine.upgrade_package(formation_instance)
    |> case do
      {:ok, upgrade_package_output} ->
        Instellar.transition_instance(
          formation_instance.slug,
          install,
          "complete",
          comment: upgrade_package_output
        )

      {:error, error} ->
        Instellar.transition_instance(
          formation_instance.slug,
          install,
          "fail",
          comment: error
        )

        {:error, error}
    end
  end

  defp handle_upgrade(
         {:deactivate_and_bootsrap, formation_instance},
         _install,
         args
       ) do
    args
    |> Map.merge(%{"mode" => "deactivate_and_boot"})
    |> Instance.Cleanup.new()
    |> Oban.insert()
  end
end
