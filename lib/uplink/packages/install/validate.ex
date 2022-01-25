defmodule Uplink.Packages.Install.Execute do
  use Oban.Worker, queue: :validate_install, max_attempts: 1

  alias Uplink.{
    Clients,
    Packages,
    Cache,
    Repo
  }

  alias Packages.{
    Install,
    Metadata
  }

  alias Clients.{
    Instellar,
    LXD
  }

  import Ecto.Query,
    only: [where: 3, preload: 2]

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  def perform(%Oban.Job{args: %{"install_id" => install_id}}) do
    %Install{} =
      install =
      Install
      |> where(
        [i],
        i.current_state == ^"validating"
      )
      |> preload([:deployment])
      |> Repo.get(install_id)

    install
    |> retrieve_metadata()
    |> ensure_profile_exists()
  end

  defp retrieve_metadata(%Install{deployment: deployment} = install) do
    signature = compute_signature(deployment.hash)

    {:deployment, signature, install.instellar_installation_id}
    |> Cache.get()
    |> case do
      %Metadata{} = metadata ->
        %{install: install, metadata: metadata}

      nil ->
        fetch_deployment_metadata(install)
    end
  end

  defp fetch_deployment_metadata(%Install{deployment: deployment} = install) do
    with {:ok, metadata_params} <- Instellar.deployment_metadata(deployment),
         {:ok, %Metadata{} = metadata} <-
           Packages.parse_metadata(metadata_params) do
      signature = compute_signature(deployment.hash)

      Cache.put(
        {:deployment, signature, install.instellar_installation_id},
        metadata
      )

      %{install: install, metadata: metadata}
    end
  end

  defp ensure_profile_exists(%{install: install, metadata: metadata} = params) do
    profile_name = Packages.profile_name(metadata)

    with %LXD.Profile{config: config} <-
           LXD.list_profiles()
           |> Enum.find(fn profile ->
             profile.name == profile_name
           end),
         {:ok, :profile_valid} <- validate_profile(config) do
    else
      nil ->
        profile_params = %{
          "name" => profile_name,
          "description" => "installation #{install.instellar_installation_id}",
          "config" => %{
            "user.managed_by" => "uplink"
          }
        }

        create_profile(profile_params)
    end
  end

  defp validate_profile(%LXD.Profile{config: config}) do
    if Enum.any?(config, &managed_by_uplink/1) do
      {:ok, :profile_valid}
    else
      {:error, :profile_invalid}
    end
  end

  defp create_profile(profile_params) do
    # add code to create profile
  end

  defp managed_by_uplink({key, value}) do
    key == "user.managed_by" and value == "uplink"
  end
end
