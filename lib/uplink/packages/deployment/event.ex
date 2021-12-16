defmodule Uplink.Packages.Deployment.Event do
  alias Uplink.{
    Members,
    Packages
  }

  alias Members.Actor
  alias Packages.Deployment

  use Eventful,
    parent: {:deployment, Deployment},
    actor: {:actor, Actor}

  alias Deployment.Transitions

  handle(:transitions, using: Transitions)
end
