defmodule Uplink.Packages.Instance.Install do
  use Oban.Worker, queue: :process_instance, max_attempts: 5

  alias Uplink.{
    Clients,
    Packages,
    Repo
  }

  alias Clients.{
    LXD,
    Instellar
  }

  alias Packages.Install

  @install_state ~s(executing)

  import Ecto.Query, only: [where: 3, preload: 2]

  def perform(
        %Oban.Job{
          args: %{
            "formation_instance" => formation_instance_params,
            "install_id" => install_id
          }
        } = job
      ) do
    %Install{} =
      install =
      Install
      |> where([i], i.current_state == @install_state)
      |> preload([:deployment])
      |> Repo.get(install_id)

    formation_instance =
      Formation.Lxd.Instance.new(%{
        slug: formation_instance_params["slug"],
        url: formation_instance_params["url"],
        credential: formation_instance_params["credential"],
        package: %{
          slug: formation_instance_params["package"]["slug"]
        }
      })

    LXD.client()
    |> Formation.Lxd.Instance.add_package_and_restart(formation_instance)
    |> case do
      {:ok, add_package_output} ->
        Instellar.transition_instance(
          formation_instance.slug,
          install,
          "complete",
          comment: add_package_output
        )

      {:error, error} ->
        if job.attempt == job.max_attempts do
          Instellar.transition_instance(
            formation_instance.slug,
            install,
            "fail",
            comment: "[Uplink.Packages.Instance.Install]"
          )
        end

        {:error, error}
    end
  end
end
