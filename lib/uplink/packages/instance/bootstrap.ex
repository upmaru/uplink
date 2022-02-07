defmodule Uplink.Packages.Instance.Bootstrap do
  use Oban.Worker, queue: :process_instance, max_attempts: 1

  alias Uplink.{
    Members,
    Clients,
    Packages,
    Repo
  }

  alias Clients.LXD
  alias LXD.Cluster
  alias Cluster.Member

  alias Members.Actor

  alias Packages.Install

  @default_params %{
    "ephemeral" => false,
    "type" => "container"
  }

  @install_state ~s(executing)

  import Ecto.Query, only: [where: 3, preload: 2]

  def perform(%Oban.Job{
        args: %{
          "instance" => %{
            "slug" => name,
            "node" => %{
              "slug" => node_name
            }
          },
          "install_id" => install_id,
          "actor_id" => actor_id
        }
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

    with %{metadata: metadata} <- Packages.build_install_state(install, actor),
         members when is_list(members) <- LXD.list_cluster_members(),
         %Member{server_name: node, architecture: architecture} <-
           members
           |> Enum.find(fn member ->
             member.server_name == node_name
           end) do
      profile_name = Packages.profile_name(metadata)

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

      formation_instance =
        Formation.Lxd.Instance.new(%{
          slug: name,
          # repository url for apk
          url: "",
          credential: %{
            "public_key" => metadata.package.credential.public_key
          },
          package: %{
            slug: metadata.package.slug
          }
        })

      LXD.create_client()
      |> Formation.Lxd.create(node_name, instance_params)
      |> Formation.Lxd.start(name)
      |> Formation.Lxd.setup(formation_instance)
    end
  end
end
