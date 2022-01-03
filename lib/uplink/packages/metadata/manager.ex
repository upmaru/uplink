defmodule Uplink.Packages.Metadata.Manager do
  alias Uplink.Packages.Metadata

  defdelegate parse(params),
    to: Metadata
end
