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
  def get_or_create(%App{id: app_id} = app, params) do
    hash = Map.get(params, :hash) || Map.get(params, "hash")
    channel = Map.get(params, :channel) || Map.get(params, "channel")

    Deployment
    |> Repo.get_by(app_id: app_id, hash: hash, channel: channel)
    |> case do
      nil ->
        create(app, params)

      %Deployment{} = deployment ->
        {:ok, deployment}
    end
  end

  def create(%App{id: app_id}, params) do
    %Deployment{app_id: app_id}
    |> Deployment.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, deployment} ->
        {:ok, deployment}

      {:error,
       %Ecto.Changeset{
         changes: %{hash: hash, channel: channel},
         errors: [
           hash:
             {_,
              [
                constraint: :unique,
                constraint_name: _
              ]}
         ]
       }} ->
        {:ok,
         Repo.get_by!(Deployment, app_id: app_id, hash: hash, channel: channel)}

      error ->
        error
    end
  end

  def update(%Deployment{} = deployment, params) do
    deployment
    |> Deployment.update_changeset(params)
    |> Repo.update()
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
