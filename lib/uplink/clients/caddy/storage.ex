defmodule Uplink.Clients.Caddy.Storage do
  @storage_modules %{
    "s3" => __MODULE__.S3
  }

  def parse(%{module: module_name} = params) do
    module = Map.fetch!(@storage_modules, module_name)
    module.parse(params)
  end
end
