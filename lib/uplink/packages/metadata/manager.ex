defmodule Uplink.Packages.Metadata.Manager do
  alias Uplink.Packages.Metadata
  alias Metadata.Storage

  def render_storage(%Storage{type: "s3", credential: credential} = storage) do
    ExAws.Config.new(:s3,
      access_key_id: Map.get(credential, "access_key_id"),
      secret_access_key: Map.get(credential, "secret_access_key"),
      host: storage.host,
      port: storage.port,
      scheme: storage.scheme,
      region: storage.region
    )
  end
end