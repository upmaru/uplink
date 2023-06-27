defmodule Uplink.Drivers do
  @drivers %{
    "database/postgresql" => __MODULE__.Database.Postgresql
  }

  def perform(module, params) do
    driver = Map.fetch!(@drivers, module)
    driver.perform(params)
  end
end
