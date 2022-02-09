defmodule Uplink.Packages.Metadata.Manager do
  alias Uplink.Packages.Metadata

  defdelegate parse(params),
    to: Metadata

  def profile_name(%Metadata{installation: installation}),
    do:
      Enum.join(
        [
          installation.channel.package.organization.slug,
          installation.channel.package.slug,
          installation.id
        ],
        "-"
      )
end
