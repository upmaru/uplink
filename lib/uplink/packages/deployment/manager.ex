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
  
  @spec create(map) :: {:ok, %Deployment{}}
  def create(params) do
    %Deployment{}
    |> Deployment.changeset(params)
    |> Repo.insert()
  end
end