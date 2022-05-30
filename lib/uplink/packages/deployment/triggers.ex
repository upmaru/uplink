defmodule Uplink.Packages.Deployment.Triggers do
  use Eventful.Trigger

  alias Uplink.{
    Packages,
    Repo
  }

  alias Packages.{
    Deployment,
    Install
  }

  alias Deployment.Prepare

  import Ecto.Query, only: [where: 3]

  Deployment
  |> trigger([currently: "preparing"], fn event, deployment ->
    %{actor_id: event.actor_id, deployment_id: deployment.id}
    |> Prepare.new()
    |> Oban.insert()
  end)

  Deployment
  |> trigger([currently: "live"], fn event, deployment ->
    event = Repo.preload(event, [:actor])

    stream =
      Install
      |> where(
        [i],
        i.current_state == ^"created" and
          i.deployment_id == ^deployment.id
      )
      |> Repo.stream()

    Repo.transaction(fn ->
      stream
      |> Enum.each(fn install ->
        Packages.transition_install_with(install, event.actor, "validate")
      end)
    end)

    {:ok, :live}
  end)
end
