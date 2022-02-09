defmodule Uplink.Packages.Instance.Upgrade do
  use Oban.Worker, queue: :process_instance, max_attempts: 1

  def perform(%Oban.Job{
        args: %{"install_id" => install_id, "actor_id" => actor_id}
      }) do
    :ok
  end
end
