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

  alias Packages.Install

  def perform(%Oban.Job{
        args: %{
          "instance" => %{
            "slug" => name,
            "node" => %{
              "slug" => _node_name
            }
          },
          "install_id" => install_id
        }
      }) do
    client = LXD.client()

    %Install{} =
      install =
      Install
      |> Repo.get(install_id)
      |> Repo.preload([:deployment])

    with {:ok, _} <- Formation.Lxd.stop(client, name),
         {:ok, _} <- Formation.Lxd.delete(client, name) do
      Instellar.transition_instance(name, install, "fail",
        comment: "[Uplink.Packages.Instance.Cleanup]"
      )
    end
  end
end
