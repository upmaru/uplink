defmodule Uplink.Packages.Install.Execute do
  use Oban.Worker, queue: :execute_install, max_attempts: 1

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

  alias Clients.Instellar

  import Ecto.Query,
    only: [where: 3, preload: 2]

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  def perform(%Oban.Job{args: %{"install_id" => install_id}}) do
    %Install{} =
      install =
      Install
      |> where([i], i.current_state == ^"executing")
      |> preload([:deployment])
      |> Repo.get(install_id)

    install
    |> retrieve_metadata()
    |> sync_instances_state()
  end

  defp retrieve_metadata(%Install{deployment: deployment} = install) do
    signature = compute_signature(deployment.hash)

    {:deployment, signature, install.instellar_installation_id}
    |> Cache.get()
    |> case do
      %Metadata{} = metadata ->
        metadata

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

      metadata
    end
  end

  defp sync_instances_state(%Metadata{instances: instances}) do
    {:ok, instances}
  end
end
