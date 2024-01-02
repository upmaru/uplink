defmodule Uplink.Data.Pro do
  alias Uplink.Drivers
  alias Uplink.Clients.Instellar

  alias Formation.Postgresql.Credential

  def match_postgresql_component(%{"generator" => %{"module" => module}}),
    do: module == "database/postgresql"

  def maybe_provision_postgresql_instance(%{"id" => component_id}) do
    with {:ok, %{"credential" => component_credential} = component_params} <-
           Instellar.get_component(component_id),
         {:ok, %{"credential" => credential}} <-
           provision_component_instance(
             component_params,
             component_id
           ) do
      credential
      |> maybe_merge_certificate(component_credential)
      |> Credential.create()
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

  defp maybe_merge_certificate(credential, %{"certificate" => certificate}) do
    Map.put(credential, "certificate", certificate)
  end

  defp maybe_merge_certificate(credential, _), do: credential
end
