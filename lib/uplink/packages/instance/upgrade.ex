defmodule Uplink.Packages.Instance.Upgrade do
  use Oban.Worker,
    queue: :process_instance,
    max_attempts: 1,
    unique: [
      fields: [:args, :worker],
      keys: [:install_id],
      states: [:executing]
    ]

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

  @install_state ~s(executing)

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
      |> where(
        [i],
        i.current_state == ^@install_state
      )
      |> preload([:deployment])
      |> Repo.get(install_id)

    with %{metadata: %{channel: channel}} <-
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
      |> handle_upgrade(job)
    end
  end

  defp validate_stack(
         formation_instance,
         %Install{
           id: install_id,
           deployment: incoming_deployment
         } = install
       ) do
    Install
    |> where(
      [i],
      i.id != ^install_id and
        i.current_state == "completed"
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

  defp handle_upgrade({:upgrade, formation_instance, install}, %Job{} = job) do
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
        handle_error(error, job)
    end
  end

  defp handle_upgrade(
         {:deactivate_and_bootstrap, _formation_instance, _install},
         %Job{args: args}
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
end
