defmodule Uplink.Clients.Instellar do
  alias __MODULE__.{
    Installation
  }

  defdelegate deployment_metadata(deployment),
    to: Installation,
    as: :metadata
end
