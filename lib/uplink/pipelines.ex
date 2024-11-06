defmodule Uplink.Pipelines do
  alias Uplink.Cache

  def get_monitors(context) do
    Cache.get({:monitors, context}) || []
  end

  def append_monitors(context, monitors) do
    Cache.get_and_update({:monitors, context}, fn existing_monitors ->
      {existing_monitors, existing_monitors ++ monitors}
    end)
  end

  def start(module) do
    spec = %{
      id: module,
      start: {module, :start_link, []}
    }

    Pogo.DynamicSupervisor.start_child(Uplink.PipelineSupervisor, spec)
  end

  def list do
    Pogo.DynamicSupervisor.which_children(Uplink.PipelineSupervisor, :global)
  end
end
