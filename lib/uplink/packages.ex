defmodule Uplink.Packages do
  
  defdelegate get_deployment(id), 
    to: __MODULE__.Manager,
    as: :get 
  
  defdelegate create_deployment(params),
    to: __MODULE__.Manager,
    as: :create
end