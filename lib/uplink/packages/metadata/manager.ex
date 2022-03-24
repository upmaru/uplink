defmodule Uplink.Packages.Metadata.Manager do
  alias Uplink.Packages.Metadata

  defdelegate parse(params),
    to: Metadata

  def profile_name(%Metadata{id: id, channel: channel}),
    do:
      Enum.join(
        [
          channel.package.organization.slug,
          channel.package.slug,
          id
        ],
        "-"
      )
end
