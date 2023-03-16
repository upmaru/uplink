defmodule Uplink.Members do
  alias __MODULE__.Actor

  def build_params(params) do
    Actor.Params.build(params)
  end

  defdelegate get_bot!(),
    to: Actor.Manager,
    as: :bot!

  defdelegate get_or_create_actor(params),
    to: Actor.Manager,
    as: :get_or_create
end
