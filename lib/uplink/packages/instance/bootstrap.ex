defmodule Uplink.Packages.Instance.Bootstrap do
  use Oban.Worker, queue: :bootstrap_instance, max_attempts: 1

  @default_params %{
    "architecture" => "x86_64",
    "ephemeral" => false,
    "type" => "container"
  }

  def perform(%Oban.Job{args: %{"name" => name}}) do
    instance_params =
      Map.merge(@default_params, %{
        "name" => name,
        "profiles" => []
      })
  end
end
