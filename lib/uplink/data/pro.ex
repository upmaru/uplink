defmodule Uplink.Data.Pro do
  alias Uplink.Drivers
  alias Uplink.Clients.Instellar

  def match_postgresql_component(%{"generator" => %{"module" => module}}),
    do: module == "database/postgresql"

  def maybe_provision_postgresql_instance(%{"id" => component_id}) do
    case Instellar.get_component(component_id) do
      {:ok, component_params} ->
        provision_component_instance(component_params, component_id)

      {:error, error} ->
        {:error, error}
    end
  end

  def maybe_provision_postgresql_instance(nil),
    do: {:error, :component_not_found}

  defp provision_component_instance(
         %{
           "generator" => %{"module" => module},
           "credential" => credential_params
         },
         component_id
       ) do
    uuid = Ecto.UUID.generate()

    id =
      uuid
      |> String.split("-")
      |> List.first()

    [_, component_type] = String.split(module, "/")

    name = "#{component_type}-#{id}"

    with {:ok, variable_attributes} <-
           Instellar.create_uplink_variable(%{
             "variable" => %{
               "key" => "DATABASE",
               "value" => "ecto:///"
             }
           }),
         {:ok, credential} <-
           Drivers.perform(
             :provision,
             module,
             %{"credential" => credential_params}
           ),
         {:ok, component_instance_attributes} <-
           Instellar.create_component_instance(component_id, %{
             "variable_id" => variable_attributes["id"],
             "instance" => %{
               "name" => name,
               "credential" => Map.from_struct(credential)
             }
           }) do
      {:ok, component_instance_attributes}
    end
  end
end
