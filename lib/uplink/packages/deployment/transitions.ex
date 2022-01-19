defmodule Uplink.Packages.Deployment.Transitions do
  alias Uplink.Packages.Deployment

  @behaviour Eventful.Handler
  use Eventful.Transition, repo: Uplink.Repo

  Deployment
  |> transition(
    [from: "created", to: "preparing", via: "prepare"],
    fn changes -> transit(changes, Deployment.Triggers) end
  )

  Deployment
  |> transition(
    [from: "preparing", to: "live", via: "complete"],
    fn changes -> transit(changes) end
  )

  Deployment
  |> transition(
    [from: "preparing", to: "failed", via: "failed"],
    fn changes -> transit(changes) end
  )
end
