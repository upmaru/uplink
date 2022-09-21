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

  import Ecto.Query,
    only: [where: 3, join: 4, preload: 2, limit: 2, order_by: 3]

  @spec get(integer()) :: %Deployment{}
  def get(id) do
    Repo.get(Deployment, id)
  end

  @spec get_latest(binary, binary) :: %Deployment{} | nil
  def get_latest(slug, channel) do
    Deployment
    |> join(:inner, [d], app in assoc(d, :app))
    |> where(
      [d, app],
      app.slug == ^slug and
        d.channel == ^channel and
        d.current_state == ^"live"
    )
    |> order_by([d], desc: d.inserted_at)
    |> preload([:archive])
    |> limit(1)
    |> Repo.one()
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
