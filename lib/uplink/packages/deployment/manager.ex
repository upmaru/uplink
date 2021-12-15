defmodule Uplink.Packages.Deployment.Manager do
  alias Uplink.{
    Packages,
    Repo
  }

  alias Packages.Deployment

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
end
