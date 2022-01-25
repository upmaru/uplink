defmodule Uplink.Packages.Metadata.Manager do
  alias Uplink.Packages.Metadata

  defdelegate parse(params),
    to: Metadata

  def profile_name(%Metadata{package: package, installation: installation}),
    do:
      Enum.join([package.organization.slug, package.slug, installation.id], "-")
end
