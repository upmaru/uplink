defmodule Uplink.Drivers.Database do
  defmodule Postgresql do
    def perform(%{"credential" => credential_params}) do
      with {:ok, master_credential} <-
             Formation.Postgresql.Credential.create(credential_params),
           {:ok, generated_credential} <-
             Formation.Postgresql.create_user_and_database(master_credential) do
        {:ok, generated_credential}
      end
    end
  end
end
