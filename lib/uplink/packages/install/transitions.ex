defmodule Uplink.Packages.Install.Transitions do
  alias Uplink.Packages.Install

  @behaviour Eventful.Handler
  use Eventful.Transition, repo: Uplink.Repo

  Install
  |> transition(
    [from: "created", to: "deploying", via: "deploy"],
    fn changes -> transit(changes) end
  )

  Install
  |> transition(
    [from: "deploying", to: "completed", via: "complete"],
    fn changes -> transit(changes) end
  )
end
