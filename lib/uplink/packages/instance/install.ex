defmodule Uplink.Packages.Instance.Install do
  use Oban.Worker, queue: :instance, max_attempts: 5

  alias Uplink.{
    Clients,
    Packages,
    Repo
  }

  alias Clients.{
    LXD,
    Caddy,
    Instellar
  }

  alias Packages.Install

  import Ecto.Query, only: [preload: 2]

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
      |> preload([:deployment])
      |> Repo.get(install_id)

    formation_instance = Formation.new_lxd_instance(formation_instance_params)

    LXD.client()
    |> Formation.add_package_and_restart_lxd_instance(formation_instance)
    |> case do
      {:ok, add_package_output} ->
        Caddy.schedule_config_reload(install)

        Instellar.transition_instance(
          formation_instance.slug,
          install,
          "complete",
          comment: add_package_output
        )

      {:error, %{"error" => "Instance is not running"}} ->
        {:snooze, 5}

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
