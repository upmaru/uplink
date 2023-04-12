defmodule Uplink.Packages.Instance.Cleanup do
  use Oban.Worker, queue: :instance, max_attempts: 3

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

  alias Packages.{
    Install
  }

  @cleanup_mappings %{
    "failing" => "fail",
    "deactivating" => "off"
  }

  def perform(%Oban.Job{
        args:
          %{
            "instance" => %{
              "slug" => name,
              "node" => %{
                "slug" => _node_name
              }
            },
            "install_id" => install_id,
            "actor_id" => actor_id
          } = args
      }) do
    %Actor{} = actor = Repo.get(Actor, actor_id)

    client = LXD.client()

    %Install{} =
      install =
      Install
      |> Repo.get(install_id)
      |> Repo.preload([:deployment])

    %{metadata: metadata} = Packages.build_install_state(install, actor)

    project_name = Packages.get_project_name(client, metadata)

    lxd = Formation.Lxd.impl()

    with {:ok, _} <-
           lxd.get_instance(client, name, query: [project: project_name]),
         {:ok, _} <- Formation.lxd_stop(client, name, project: project_name),
         {:ok, _} <- Formation.lxd_delete(client, name, project: project_name) do
      finalize(name, install, Map.get(args, "mode", "cleanup"), args)
    else
      {:error, %{"error_code" => 404}} ->
        finalize(name, install, "cleanup", args)

      error ->
        error
    end
  end

  defp finalize(name, install, "cleanup", %{
         "instance" => %{"current_state" => current_state}
       }) do
    event_name = Map.get(@cleanup_mappings, current_state, "off")

    Caddy.schedule_config_reload(install)

    Instellar.transition_instance(name, install, event_name,
      comment: "[Uplink.Packages.Instance.Cleanup]"
    )
  end

  defp finalize(name, install, "deactivate_and_boot", args) do
    comment = Map.get(args, "comment", "[Uplink.Packages.Instance.Cleanup]")

    with {:ok, _transition} <-
           Instellar.transition_instance(name, install, "deactivate",
             comment: comment
           ) do
      Instellar.transition_instance(name, install, "boot", comment: comment)
    end
  end
end
