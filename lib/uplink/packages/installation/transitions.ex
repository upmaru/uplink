defmodule Uplink.Packages.Installation.Transitions do
  alias Uplink.Packages.Installation

  @behaviour Eventful.Handler
  use Eventful.Transition, repo: Uplink.Repo

  Installation
  |> transition(
    [from: "created", to: "deploying", via: "deploy"],
    fn changes -> transit(changes) end
  )

  Installation
  |> transition(
    [from: "deploying", to: "completed", via: "complete"],
    fn changes -> transit(changes) end
  )
end
