defmodule Uplink.Drivers do
  @drivers Application.compile_env(:uplink, :drivers, [])

  @driver_mapping %{
    "database/postgresql" => __MODULE__.Database.Postgresql,
    "bucket/aws-s3" => Keyword.get(@drivers, :aws_s3, __MODULE__.Bucket.Aws)
  }

  defmodule Behaviour do
    @callback perform(map(), Keyword.t()) :: {:ok, map()}
  end

  def perform(module, params, options) do
    driver = Map.fetch!(@driver_mapping, module)
    driver.perform(params, options)
  end
end
