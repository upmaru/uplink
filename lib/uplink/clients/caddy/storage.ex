defmodule Uplink.Clients.Caddy.Storage do
  @storage_modules %{
    "s3" => __MODULE__.S3
  }

  def parse(%{"module" => module_name} = params) do
    module = Map.fetch!(@storage_modules, module_name)
    module.parse(params)
  end

  def parse(%{"type" => module_name, "credential" => credential} = params) do
    module = Map.fetch!(@storage_modules, module_name)
    storage_config = Uplink.Clients.Caddy.config(:storage)

    module.parse(%{
      module: module_name,
      host: params["host"],
      bucket: params["bucket"],
      access_id: credential["access_key_id"],
      secret_key: credential["secret_access_key"],
      prefix: storage_config.prefix
    })
  end
end
