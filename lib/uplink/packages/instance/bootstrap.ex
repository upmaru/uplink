defmodule Uplink.Packages.Instance.Bootstrap do
  use Oban.Worker,
    queue: :process_instance,
    max_attempts: 2,
    unique: [fields: [:args, :worker], keys: [:install_id]]

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

  @install_state ~s(executing)

  import Ecto.Query, only: [where: 3, preload: 2]

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
      |> where(
        [i],
        i.current_state == ^@install_state
      )
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

      formation_instance_params = %{
        "slug" => name,
        "url" => package_distribution_url,
        "credential" => %{
          "public_key" => package.credential.public_key
        },
        "package" => %{
          "slug" => package.slug
        }
      }

      formation_instance =
        Formation.Lxd.Instance.new(%{
          slug: name,
          url: package_distribution_url,
          credential: %{
            "public_key" => package.credential.public_key
          },
          package: %{
            slug: package.slug
          }
        })

      LXD.client()
      |> Formation.Lxd.create(node_name, instance_params)
      |> Formation.Lxd.start(name)
      |> Formation.Lxd.Instance.setup(formation_instance)
      |> case do
        {:ok, _message} ->
          %{
            formation_instance: formation_instance_params,
            install_id: install.id
          }
          |> Instance.Install.new()
          |> Oban.insert()

        {:error, error} ->
          job_args
          |> Packages.Instance.Cleanup.new()
          |> Oban.insert()

          Instellar.transition_instance(name, install, "fail", comment: error)
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
end
