defmodule Uplink.Members.Actor.Manager do
  alias Uplink.{
    Members,
    Repo
  }

  alias Members.Actor

  def get(%{"identifier" => identifier}), do: get(identifier)

  def get(identifier) do
    Actor
    |> Repo.get_by(identifier: identifier, provider: "instellar")
    |> case do
      %Actor{} = actor ->
        actor

      nil ->
        {:actor, :not_found}
    end
  end

  def bot! do
    params = %{identifier: "uplink-bot", provider: "internal"}

    Actor
    |> Repo.get_by(params)
    |> case do
      %Actor{} = actor ->
        actor

      nil ->
        %Actor{}
        |> Actor.changeset(params)
        |> Repo.insert!()
    end
  end

  def create(params) do
    %Actor{}
    |> Actor.changeset(params)
    |> Repo.insert()
  end
end
