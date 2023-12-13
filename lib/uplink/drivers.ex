defmodule Uplink.Drivers do
  @drivers Application.compile_env(:uplink, :drivers, [])

  @driver_mapping %{
    "database/postgresql" => __MODULE__.Database.Postgresql,
    "bucket/aws-s3" => Keyword.get(@drivers, :aws_s3, __MODULE__.Bucket.Aws)
  }

  defmodule Behaviour do
    @callback provision(map(), Keyword.t()) :: {:ok, map()}
    @callback modify(map(), Keyword.t()) :: {:ok, map()}
  end

  def perform(call, module, params, options) do
    driver = Map.fetch!(@driver_mapping, module)
    apply(driver, call, [params, options])
  end
end
