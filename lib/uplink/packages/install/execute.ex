defmodule Uplink.Packages.Install.Execute do
  use Oban.Worker, queue: :execute_install, max_attempts: 1

  alias Uplink.{
    Clients,
    Members,
    Packages,
    Cache,
    Repo
  }

  alias Members.Actor

  alias Packages.Install

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  import Ecto.Query,
    only: [where: 3, preload: 2]

  def perform(%Oban.Job{
        args: %{"install_id" => install_id, "actor_id" => actor_id}
      }) do
    %Actor{} = actor = Repo.get(Actor, actor_id)

    %Install{} =
      install =
      Install
      |> where(
        [i],
        i.current_state == ^"executing"
      )
      |> preload([:deployment])
      |> Repo.get(install_id)

    install
    |> Packages.build_install_state(actor)
  end
end
