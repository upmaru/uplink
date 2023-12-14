defmodule Uplink.Drivers.Database do
  defmodule Postgresql do
    @behaviour Uplink.Drivers.Behaviour

    def provision(%{"credential" => credential_params}, options \\ []) do
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

    def modify(
          %{
            "credential" => credential_params,
            "component_instance" => _component_instance_attributes
          },
          _options \\ []
        ) do
      Formation.Postgresql.Credential.create(credential_params)
    end
  end
end
