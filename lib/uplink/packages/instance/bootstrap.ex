defmodule Uplink.Packages.Instance.Bootstrap do
  use Oban.Worker, queue: :process_instance, max_attempts: 1

  @default_params %{
    "architecture" => "x86_64",
    "ephemeral" => false,
    "type" => "container"
  }

  def perform(%Oban.Job{args: %{
    "instance" => instance_params, 
    "install_id" => install_id, 
    "actor_id" => actor_id
  }}) do
    instance_params =
      Map.merge(@default_params, %{
        "name" => name,
        "profiles" => []
      })
  end
end
