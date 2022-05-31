defmodule Uplink.Packages.Install.Transitions do
  alias Uplink.Packages.Install

  @behaviour Eventful.Handler
  use Eventful.Transition, repo: Uplink.Repo

  Install
  |> transition(
    [from: "created", to: "validating", via: "validate"],
    fn changes -> transit(changes, Install.Triggers) end
  )

  Install
  |> transition(
    [from: "validating", to: "executing", via: "execute"],
    fn changes -> transit(changes, Install.Triggers) end
  )

  Install
  |> transition(
    [from: "validating", to: "paused", via: "pause"],
    fn changes -> transit(changes) end
  )

  Install
  |> transition(
    [from: "executing", to: "completed", via: "complete"],
    fn changes -> transit(changes) end
  )

  Install
  |> transition(
    [from: "executing", to: "failed", via: "fail"],
    fn changes -> transit(changes) end
  )
end
