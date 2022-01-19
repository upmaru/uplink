defmodule Uplink.Packages.Deployment.Manager do
  alias Uplink.{
    Packages,
    Repo
  }

  alias Packages.{
    App,
    Deployment
  }

  alias Deployment.Event

  @spec get(integer()) :: %Deployment{}
  def get(id) do
    Repo.get(Deployment, id)
  end

  @spec get_or_create(%App{}, map) :: {:ok, %Deployment{}}
  def get_or_create(%App{id: app_id}, params) do
    hash = Map.get(params, :hash) || Map.get(params, "hash")

    Deployment
    |> Repo.get_by(app_id: app_id, hash: hash)
    |> case do
      nil ->
        %Deployment{app_id: app_id}
        |> Deployment.changeset(params)
        |> Repo.insert()

      %Deployment{} = deployment ->
        {:ok, deployment}
    end
  end

  def transition_with(deployment, actor, event_name, opts \\ []) do
    comment = Keyword.get(opts, :comment)

    deployment
    |> Event.handle(actor, %{
      domain: "transitions",
      name: event_name,
      comment: comment
    })
  end
end
