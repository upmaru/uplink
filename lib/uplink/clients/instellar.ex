defmodule Uplink.Clients.Instellar do
  alias __MODULE__.{
    Installation,
    Instance,
    Self
  }

  @endpoint "https://web.instellar.app/uplink"

  defdelegate get_self(),
    to: Self,
    as: :show

  defdelegate deployment_metadata(install),
    to: Installation,
    as: :metadata

  defdelegate transition_instance(instance, install, event_name),
    to: Instance,
    as: :transition

  def endpoint, do: config(:endpoint) || @endpoint

  def config(key) do
    Application.get_env(:uplink, __MODULE__)
    |> Keyword.get(key)
  end
end
