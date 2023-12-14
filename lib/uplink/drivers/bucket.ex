defmodule Uplink.Drivers.Bucket do
  defmodule Aws do
    @behaviour Uplink.Drivers.Behaviour

    def provision(%{"credential" => credential_params}, options \\ []) do
      credential_params = Map.put(credential_params, "type", "component")

      with {:ok, master_credential} <-
             Formation.S3.Credential.create(credential_params),
           {:ok, generated_credential} <-
             Formation.Aws.create_credential_and_bucket(
               master_credential,
               options
             ) do
        {:ok, generated_credential}
      end
    end

    def modify(
          %{
            "credential" => credential_params,
            "component_instance" => component_instance_attributes
          },
          options \\ []
        ) do
      credential_params = Map.put(credential_params, "type", "component")

      with {:ok, master_credential} <-
             Formation.S3.Credential.create(credential_params),
           {:ok, updated_credential} <-
             Formation.Aws.update_credential_and_bucket(
               master_credential,
               component_instance_attributes,
               options
             ) do
        {:ok, updated_credential}
      end
    end
  end
end
