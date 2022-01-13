defmodule Uplink.Packages.Installation.Transitions do
  alias Uplink.Packages.Installation

  @behaviour Eventful.Handler
  use Eventful.Transition, repo: Uplink.Repo

  Installation
  |> transition(
    [from: "synced", to: "syncing", via: "sync"],
    fn changes -> transit(changes) end
  )

  Installation
  |> transition(
    [from: "syncing", to: "synced", via: "done"],
    fn changes -> transit(changes) end
  )
end
