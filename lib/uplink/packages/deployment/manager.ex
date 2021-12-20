defmodule Uplink.Packages.Deployment.Manager do
  alias Uplink.{
    Packages,
    Repo
  }

  alias Packages.Deployment
  alias Deployment.Event

  @spec get(integer()) :: %Deployment{}
  def get(id) do
    Repo.get(Deployment, id)
  end

  @spec create(%Packages.Installation{}, map) :: {:ok, %Deployment{}}
  def create(installation, params) do
    %Deployment{installation_id: installation.id}
    |> Deployment.changeset(params)
    |> Repo.insert()
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
