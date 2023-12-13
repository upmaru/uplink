defmodule Uplink.Components.Instance.Modify do
  use Oban.Worker, queue: :components, max_attempts: 1

  alias Uplink.Drivers
  alias Uplink.Clients.Instellar

  def perform(%Oban.Job{args: %{"component_id" => component_id} = job_params}) do
    case Instellar.get_component(component_id) do
      {:ok, component_params} ->
        handle_perform(component_params, job_params)

      {:error, error} ->
        {:error, error}
    end
  end

  defp handle_peroform(
         %{
           "generator" => %{"module" => module},
           "credential" => credential_params
         },
         %{
           "component_id" => component_id,
           "component_instance_id" => component_instance_id,
           "variable_id" => variable_id
         }
       ) do
    options =
      job_args
      |> Map.get("arguments", %{})
      |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)

    with {:ok, component_instance_attributes} <-
           Instellar.get_component_instance(component_id, component_instance_id),
         {:ok, credential} <-
           Drivers.perform(
             :modify,
             module,
             %{
               "credential" => credential_params,
               "component_instance" => component_instance_attributes
             },
             options
           ),
         {:ok, component_instance_attributes} <-
           Instellar.update_component_instance(
             component_id,
             component_instance_id,
             %{
               "variable_id" => variable_id,
               "instance" => %{"credential" => Map.from_struct(credential)}
             }
           ) do
      {:ok, component_instance_attributes}
    end
  end
end
