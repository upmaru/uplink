defmodule Uplink.Packages.Distribution.Manager do
  alias Uplink.Packages

  def url(%Packages.Metadata{channel: channel}) do
    hostname = System.get_env("HOSTNAME")

    internal_router_config = Application.get_env(:uplink, Uplink.Internal)

    port = Keyword.get(internal_router_config, :port)

    organization = channel.package.organization.slug
    package = channel.package.slug

    "http://#{hostname}:#{port}/distribution/#{channel.slug}/#{organization}/#{package}"
  end
end
