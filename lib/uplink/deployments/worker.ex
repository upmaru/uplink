defmodule Uplink.Deployments.Worker do
  use Que.Worker, concurrency: 1
  
  alias Uplink.Deployments
  
  def perform(deployment_entry_id) do
    %Deployments.Entry{} = Memento.transaction! fn -> 
      Memento.Query.get(Deployments.Entry, deployment_entry_id)
    end
  end
end