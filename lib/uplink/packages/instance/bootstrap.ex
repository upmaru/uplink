defmodule Uplink.Packages.Instance.Bootstrap do
  use Oban.Worker,
    queue: :instance,
    max_attempts: 1

  alias Uplink.{
    Members,
    Clients,
    Packages,
    Repo
  }

  alias Clients.{
    LXD,
    Instellar
  }

  alias LXD.Cluster
  alias Cluster.Member

  alias Members.Actor

  alias Packages.{
    Install,
    Instance
  }

  @default_params %{
    "ephemeral" => false,
    "type" => "container"
  }

  import Ecto.Query, only: [preload: 2]

  def perform(%Oban.Job{
        args:
          %{
            "instance" => %{
              "slug" => name,
              "node" => %{
                "slug" => node_name
              }
            },
            "install_id" => install_id,
            "actor_id" => actor_id
          } = job_args
      }) do
    %Actor{} = actor = Repo.get(Actor, actor_id)

    %Install{} =
      install =
      Install
      |> preload([:deployment])
      |> Repo.get(install_id)

    with %{metadata: %{channel: channel} = metadata} <-
           Packages.build_install_state(install, actor),
         members when is_list(members) <- LXD.list_cluster_members(),
         %Member{architecture: architecture} <-
           members
           |> Enum.find(fn member ->
             member.server_name == node_name
           end),
         {:ok, _transition} <-
           Instellar.transition_instance(name, install, "boot",
             comment: "[Uplink.Packages.Instance.Bootstrap]"
           ) do
      profile_name = Packages.profile_name(metadata)
      package = channel.package

      instance_params =
        Map.merge(@default_params, %{
          "name" => name,
          "architecture" => architecture,
          "profiles" => [
            profile_name,
            "default"
          ],
          "source" => %{
            "type" => "image",
            "mode" => "pull",
            "protocol" => "simplestreams",
            "server" => "https://images.linuxcontainers.org",
            "alias" => install.deployment.stack
          }
        })

      package_distribution_url = Packages.distribution_url(metadata)

      client = LXD.client()

      project_name = Packages.get_or_create_project_name(client, metadata)

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
      |> Formation.lxd_create(node_name, instance_params, project: project_name)
      |> Formation.lxd_start(name, project: project_name)
      |> Formation.setup_lxd_instance(formation_instance)
      |> case do
        {:ok, _message} ->
          %{
            instance: %{
              slug: name,
              node: %{
                slug: node_name
              }
            },
            install_id: install.id,
            actor_id: actor_id
          }
          |> Instance.Install.new()
          |> Oban.insert()

        {:error, error} ->
          # will put instance in failing
          Instellar.transition_instance(name, install, "fail",
            comment: "[Uplink.Packages.Instance.Bootstrap] #{error}"
          )
          |> handle_event(job_args)
      end
    else
      {:error, error} ->
        Packages.transition_install_with(install, actor, "fail", comment: error)

      nil ->
        Packages.transition_install_with(install, actor, "fail",
          comment: "cluster member not found"
        )
    end
  end

  defp handle_event({:ok, %{"name" => "fail"}}, %{
         "instance" => instance_params,
         "install_id" => install_id,
         "actor_id" => actor_id
       }) do
    job_args = %{
      "instance" => Map.merge(instance_params, %{"current_state" => "failing"}),
      "install_id" => install_id,
      "actor_id" => actor_id
    }

    job_args
    |> Packages.Instance.Cleanup.new()
    |> Oban.insert()
  end
end
