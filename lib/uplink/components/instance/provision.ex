defmodule Uplink.Components.Instance.Provision do
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

  defp handle_perform(
         %{
           "generator" => %{"module" => module},
           "credential" => credential_params
         },
         %{"component_id" => component_id, "variable_id" => variable_id} =
           job_args
       ) do
    uuid = Ecto.UUID.generate()

    id =
      uuid
      |> String.split("-")
      |> List.first()

    [_, component_type] = String.split(module, "/")

    name = "#{component_type}-#{id}"

    options =
      job_args
      |> Map.get("arguments", %{})
      |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)

    with {:ok, credential} <-
           Drivers.perform(
             module,
             %{"credential" => credential_params},
             options
           ),
         {:ok, component_instance_attributes} <-
           Instellar.create_component_instance(component_id, %{
             "variable_id" => variable_id,
             "instance" => %{
               "name" => name,
               "credential" => Map.from_struct(credential)
             }
           }) do
      {:ok, component_instance_attributes}
    end
  end
end
