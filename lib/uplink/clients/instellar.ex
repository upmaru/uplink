defmodule Uplink.Clients.Instellar do
  alias __MODULE__.{
    Installation,
    Self
  }

  @endpoint "https://web.instellar.app/uplink"
  
  defdelegate get_self(), 
    to: Self,
    as: :show
     

  defdelegate deployment_metadata(deployment),
    to: Installation,
    as: :metadata

  def endpoint, do: config(:endpoint) || @endpoint

  def config(key) do
    Application.get_env(:uplink, __MODULE__)
    |> Keyword.get(key)
  end
end
