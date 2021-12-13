defmodule Uplink.Packages.Deployment.Manager do
  alias Uplink.{
    Packages,
    Repo
  }
  
  @spec get(integer()) :: %Packages.Deployment{}
  def get(id) do
    Repo.get(Packages.Deployment, id)
  end
  
  @spec create(map) :: {:ok, %Packages.Deployment{}}
  def create(params) do
    
  end
end