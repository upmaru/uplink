defmodule Uplink.Members.Actor.Manager do
  alias Uplink.{
    Members,
    Repo
  }

  alias Members.Actor

  def get_or_create(params) do
    with {:ok, %{id: id, provider: provider, identifier: identifier}} <-
           Actor.Params.build(params) do
      Actor
      |> Repo.get_by(reference: id, provider: provider)
      |> case do
        %Actor{} = actor ->
          {:ok, actor}

        nil ->
          %Actor{}
          |> Actor.changeset(%{
            identifier: identifier,
            provider: provider,
            reference: id
          })
          |> Repo.insert()
      end
    else
      error -> error
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
end
