defmodule Uplink.Packages.Instance.Install do
  use Oban.Worker, queue: :instance, max_attempts: 5

  alias Uplink.{
    Clients,
    Packages,
    Members,
    Repo
  }

  alias Members.Actor

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
            "instance" => %{
              "slug" => name,
              "node" => %{
                "slug" => _node_name
              }
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

    %{metadata: metadata} = Packages.build_install_state(install, actor)
    client = LXD.client()

    project_name = Packages.get_project_name(client, metadata)
    package_distribution_url = Packages.distribution_url(metadata)
    package = metadata.channel.package

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
            comment: "[Uplink.Packages.Instance.Install] #{inspect(error)}"
          )
        end

        {:error, error}
    end
  end
end
