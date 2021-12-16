defmodule Uplink.Packages.Deployment.Transitions do
  alias Uplink.Packages.Deployment

  @behaviour Eventful.Handler
  use Eventful.Transition, repo: Uplink.Repo

  Deployment
  |> transition(
    [from: "created", to: "pending", via: "pend"],
    fn changes -> transit(changes) end
  )

  Deployment
  |> transition(
    [from: "pending", to: "processing", via: "process"],
    fn changes -> transit(changes) end
  )
end
