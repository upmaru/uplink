defmodule Uplink.Deployments.Manager do
  alias Uplink.Deployments
  
  @spec get(integer()) :: %Deployments.Entry{}
  def get(id) do
    Memento.transaction!(fn -> 
      Memento.Query.read(Deployments.Entry, id)
    end)  
  end
  
  @spec create(map) :: {:ok, %Deployments.Entry{}}
  def create(params) do
    Memento.transaction(fn -> 
      params
      |> Deployments.Entry.parse()
      |> case do
        {:ok, entry} -> 
          Memento.Query.write(entry)
      end
    end)
  end
end