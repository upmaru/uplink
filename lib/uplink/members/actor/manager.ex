defmodule Uplink.Members.Actor.Manager do
  alias Uplink.{
    Members,
    Repo
  }

  alias Members.Actor

  def get(%{"identifier" => identifier}), do: get(identifier)

  def get(identifier) do
    Actor
    |> Repo.get_by(identifier: identifier)
    |> case do
      %Actor{} = actor ->
        actor

      nil ->
        {:actor, :not_found}
    end
  end

  def create(params) do
    %Actor{}
    |> Actor.changeset(params)
    |> Repo.insert()
  end
end
