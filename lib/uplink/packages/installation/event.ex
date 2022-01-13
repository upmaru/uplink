defmodule Uplink.Packages.Installation.Event do
  alias Uplink.{
    Members,
    Packages
  }
  
  alias Members.Actor
  alias Packages.Installation
  
  use Eventful,
    parent: {:installation, Installation},
    actor: {:actor, Actor}
    
  alias Installation.Transitions
  
  handle(:transition, using: Transitions)
end