defmodule Uplink.Members do
  alias __MODULE__.Actor

  defdelegate get_actor(identifier),
    to: Actor.Manager,
    as: :get

  defdelegate create_actor(params),
    to: Actor.Manager,
    as: :create
end
