defmodule Uplink.Deployments do
  
  defdelegate get_entry(id), 
    to: __MODULE__.Manager,
    as: :get 
  
  defdelegate create_entry(params),
    to: __MODULE__.Manager,
    as: :create
end