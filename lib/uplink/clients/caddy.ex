defmodule Uplink.Clients.Caddy do
  @endpoint "http://localhost:2019"

  def default_endpoint, do: @endpoint
  
  defdelegate get_config, 
    to: __MODULE__.Config, as: :get
  
  defdelegate load_config(params), 
    to: __MODULE__.Config, as: :load

  def config(key) do
    Application.get_env(:uplink, __MODULE__)
    |> Keyword.get(key)
  end
end
