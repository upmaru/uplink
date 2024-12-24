defmodule Uplink.Caddy.Config.Hosts do
  alias Uplink.Packages.Metadata
  alias Uplink.Packages.Metadata.Port

  def routable?(%{metadata: %Metadata{main_port: nil}}), do: false

  def routable?(%{
        metadata: %Metadata{
          main_port: %{routing: %Port.Routing{}}
        }
      }),
      do: true

  def routable?(%{metadata: %Metadata{hosts: hosts}}) when length(hosts) > 0,
    do: true

  def routable?(%{metadata: %Metadata{hosts: []}}), do: false
end
