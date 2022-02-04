defmodule Uplink.Packages.Instance.Upgrade do
  use Oban.Worker, queue: :process_instance, max_attempts: 1
end