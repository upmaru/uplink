defmodule Uplink.Drivers.Bucket do
  defmodule Aws do
    def perform(%{"credential" => credential_params}, options \\ []) do
      credential_params = Map.put(credential_params, "type", "component")

      with {:ok, master_credential} <-
             Formation.S3.Credential.create(credential_params),
           {:ok, generated_credential} <-
             Formation.Aws.Bucket.create_credential_and_bucket(
               master_credential, options
             ) do
        {:ok, generated_credential}
      end
    end
  end
end
