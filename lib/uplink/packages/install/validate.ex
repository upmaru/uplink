defmodule Uplink.Packages.Install.Validate do
  use Oban.Worker, queue: :validate_install, max_attempts: 1

  alias Uplink.{
    Clients,
    Members,
    Packages,
    Repo
  }

  alias Members.Actor

  alias Packages.Install

  alias Clients.LXD

  require Logger

  import Ecto.Query,
    only: [where: 3, preload: 2]

  @state ~s(validating)

  def perform(%Oban.Job{
        args: %{"install_id" => install_id, "actor_id" => actor_id}
      }) do
    %Actor{} = actor = Repo.get(Actor, actor_id)

    %Install{} =
      install =
      Install
      |> where(
        [i],
        i.current_state == ^@state
      )
      |> preload([:deployment])
      |> Repo.get(install_id)

    install
    |> Packages.build_install_state(actor)
    |> ensure_profile_exists()
  end

  defp ensure_profile_exists(%{
         install: install,
         metadata: metadata,
         actor: actor
       }) do
    profile_name = Packages.profile_name(metadata)

    with %LXD.Profile{} = profile <-
           LXD.list_profiles()
           |> Enum.find(fn profile ->
             profile.name == profile_name
           end),
         {:ok, :profile_valid} <- validate_profile(profile) do
      Packages.transition_install_with(install, actor, "execute")
    else
      nil ->
        internal_router_config =
          Application.get_env(:uplink, Uplink.Internal, port: 4080)

        internal_router_port = Keyword.get(internal_router_config, :port)

        profile_params = %{
          "name" => profile_name,
          "description" => "#{install.id}/#{install.instellar_installation_id}",
          "config" => %{
            "user.managed_by" => "uplink",
            "user.install_variables_endpoint" =>
              "http://localhost:#{internal_router_port}/installs/#{install.id}/variables"
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
