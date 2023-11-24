defmodule Uplink.Packages.Instance.Finalize do
  use Oban.Worker, queue: :instance, max_attempts: 5

  alias Uplink.Repo
  alias Uplink.Clients.Instellar
  alias Uplink.Packages.Install

  import Ecto.Query, only: [preload: 2]

  @transition_parameters %{
    "from" => "uplink",
    "trigger" => false
  }

  def perform(%Oban.Job{
        args:
          %{
            "instance" =>
              %{
                "slug" => name
              } = instance_params,
            "comment" => comment,
            "install_id" => install_id,
            "actor_id" => actor_id
          } = args
      }) do
    %Install{} =
      install =
      Install
      |> preload([:deployment])
      |> Repo.get(install_id)

    node = Map.get(instance_params, "node", %{})

    transition_parameters =
      Map.put(@transition_parameters, "node", node["slug"])

    Instellar.transition_instance(name, install, "complete",
      comment: comment,
      parameters: transition_parameters
    )
  end
end
