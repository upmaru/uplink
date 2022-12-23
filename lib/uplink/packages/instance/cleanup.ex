defmodule Uplink.Packages.Instance.Cleanup do
  use Oban.Worker, queue: :process_instance, max_attempts: 1

  alias Uplink.{
    Clients,
    Packages,
    Repo
  }

  alias Clients.{
    LXD,
    Instellar
  }

  alias Packages.{
    Install,
    Instance
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
            "install_id" => install_id
          } = args
      }) do
    client = LXD.client()

    %Install{} =
      install =
      Install
      |> Repo.get(install_id)
      |> Repo.preload([:deployment])

    with {:ok, _} <- Formation.lxd_stop(client, name),
         {:ok, _} <- Formation.lxd_delete(client, name) do
      finalize(name, install, Map.get(args, "mode", "cleanup"), args)
    end
  end

  defp finalize(name, install, "cleanup", _args) do
    Instellar.transition_instance(name, install, "fail",
      comment: "[Uplink.Packages.Instance.Cleanup]"
    )
  end

  defp finalize(name, install, "deactivate_and_boot", args) do
    comment = Map.get(args, "comment", "[Uplink.Packages.Instance.Cleanup]")

    with {:ok, _transition} <-
           Instellar.transition_instance(name, install, "deactivate",
             comment: comment
           ) do
      args
      |> Instance.Bootstrap.new()
      |> Oban.insert()
    end
  end
end
