defmodule Uplink.Pipelines do
  alias Uplink.Cache

  @valid_contexts [:metrics]

  def get_monitors(context) when context in @valid_contexts do
    Cache.get({:monitors, context}) || []
  end

  def reset_monitors(context) when context in @valid_contexts do
    Cache.put({:monitors, context}, [])
  end

  def append_monitors(context, monitors) when context in @valid_contexts do
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
