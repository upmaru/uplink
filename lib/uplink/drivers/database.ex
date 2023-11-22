defmodule Uplink.Drivers.Database do
  defmodule Postgresql do
    @behaviour Uplink.Drivers.Behaviour

    def perform(%{"credential" => credential_params}, options \\ []) do
      with {:ok, master_credential} <-
             Formation.Postgresql.Credential.create(credential_params),
           {:ok, generated_credential} <-
             Formation.Postgresql.create_user_and_database(
               master_credential,
               options
             ) do
        {:ok, generated_credential}
      end
    end
  end
end
