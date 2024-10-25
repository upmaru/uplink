defmodule Uplink.Pipelines do
  defdelegate get_monitors(context),
    to: __MODULE__.Context,
    as: :get

  defdelegate append_monitors(context, monitors),
    to: __MODULE__.Context,
    as: :append

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
