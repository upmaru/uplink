defmodule Uplink.Packages.Distribution.Manager do
  alias Uplink.Packages

  def url(%Packages.Metadata{installation: installation}) do
    hostname = System.get_env("HOSTNAME")
    router_config = Application.get_env(:uplink, Uplink.Router)

    port = Keyword.get(router_config, :port)

    channel = installation.channel.slug
    organization = installation.channel.package.organization.slug
    package = installation.channel.package.slug

    "http://#{hostname}:#{port}/distribution/#{channel}/#{organization}/#{package}"
  end
end
