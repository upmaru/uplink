defmodule Uplink.Drivers do
  @drivers %{
    "database/postgresql" => __MODULE__.Database.Postgresql,
    "bucket/aws" => __MODULE__.Bucket.Aws
  }

  def perform(module, params) do
    driver = Map.fetch!(@drivers, module)
    driver.perform(params)
  end
end
