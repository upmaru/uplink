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
          create(%{
            identifier: identifier,
            provider: provider,
            reference: id
          })
      end
    else
      error -> error
    end
  end

  def create(%{reference: reference, provider: provider} = params) do
    %Actor{}
    |> Actor.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, actor} ->
        {:ok, actor}

      {:error,
       %Ecto.Changeset{
         errors: [
           reference:
             {_,
              [
                constraint: :unique,
                constraint_name: "actors_provider_reference_index"
              ]}
         ]
       }} ->
        {:ok, Repo.get_by!(Actor, reference: reference, provider: provider)}

      error ->
        error
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
