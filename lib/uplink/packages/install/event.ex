defmodule Uplink.Packages.Install.Event do
  alias Uplink.{
    Members,
    Packages
  }

  alias Members.Actor
  alias Packages.Install

  use Eventful,
    parent: {:install, Install},
    actor: {:actor, Actor}

  alias Install.Transitions

  handle(:transitions, using: Transitions)
end
