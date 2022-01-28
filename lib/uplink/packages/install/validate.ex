defmodule Uplink.Packages.Install.Validate do
  use Oban.Worker, queue: :validate_install, max_attempts: 1

  alias Uplink.{
    Clients,
    Members,
    Packages,
    Cache,
    Repo
  }

  alias Members.Actor

  alias Packages.{
    Install,
    Metadata
  }

  alias Clients.{
    Instellar,
    LXD
  }
  
  require Logger

  import Ecto.Query,
    only: [where: 3, preload: 2]

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  def perform(%Oban.Job{
        args: %{"install_id" => install_id, "actor_id" => actor_id}
      }) do
    %Actor{} = actor = Repo.get(Actor, actor_id)

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
    |> build_state(actor)
    |> ensure_profile_exists()
  end

  defp build_state(%Install{deployment: deployment} = install, actor) do
    signature = compute_signature(deployment.hash)

    {:deployment, signature, install.instellar_installation_id}
    |> Cache.get()
    |> case do
      %Metadata{} = metadata ->
        %{install: install, metadata: metadata, actor: actor}

      nil ->
        install
        |> fetch_deployment_metadata()
        |> Map.merge(%{install: install, actor: actor})
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

      %{metadata: metadata}
    end
  end

  defp ensure_profile_exists(
         %{install: install, metadata: metadata, actor: actor}
       ) do
    profile_name = Packages.profile_name(metadata)

    with %LXD.Profile{config: config} <-
           LXD.list_profiles()
           |> Enum.find(fn profile ->
             profile.name == profile_name
           end),
         {:ok, :profile_valid} <- validate_profile(config) do
      Packages.transition_install_with(install, actor, "execute")
    else
      nil ->
        profile_params = %{
          "name" => profile_name,
          "description" => "#{install.id}/#{install.instellar_installation_id}",
          "config" => %{
            "user.managed_by" => "uplink"
          }
        }

        case create_profile(profile_params) do
          {:ok, :profile_created} ->
            Packages.transition_install_with(install, actor, "execute")

          {:error, error} ->
            Logger.error("[Install.Execute] #{install.id} #{error}")

            Packages.transition_install_with(
              install,
              actor,
              "pause",
              comment: "error occured when attempting to create profile"
            )
        end

      {:error, :profile_invalid} ->
        Packages.transition_install_with(
          install,
          actor,
          "pause",
          comment: "profile exists but not managed by uplink"
        )
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
    LXD.client()
    |> Lexdee.create_profile(profile_params)
    |> case do
      {:ok, %{body: nil}} ->
        {:ok, :profile_created}

      {:error, %{"error" => message}} ->
        {:error, message}
    end
  end

  defp managed_by_uplink({key, value}) do
    key == "user.managed_by" and value == "uplink"
  end
end
