defmodule Uplink.Pipelines do
  use DynamicSupervisor

  def start_link(options) do
    DynamicSupervisor.start_link(__MODULE__, options, name: __MODULE__)
  end

  def start_metrics(monitors) do
    spec = {Uplink.Metrics.Pipeline, monitors: monitors}

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def init(_options) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
