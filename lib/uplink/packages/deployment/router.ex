defmodule Uplink.Packages.Deployment.Router do
  use Plug.Router
  use Uplink.Web

  alias Uplink.{
    Secret,
    Members,
    Packages,
    Cache,
    Repo
  }

  alias Packages.{
    App,
    Install,
    Deployment,
    Metadata
  }

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  plug :match

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    body_reader: {Uplink.Web.CacheBodyReader, :read_body, []},
    json_decoder: Jason

  plug Secret.VerificationPlug

  plug :dispatch

  require Logger

  post "/" do
    %{
      "actor" => actor_params,
      "installation_id" => instellar_installation_id,
      "deployment" => deployment_params
    } = conn.body_params

    with {:ok, %Metadata{} = metadata} <-
           deployment_params
           |> Map.get("metadata")
           |> Packages.parse_metadata(),
         %App{} = app <-
           metadata
           |> Metadata.app_slug()
           |> Packages.get_or_create_app(),
         {:ok, %Deployment{} = deployment} <-
           Packages.get_or_create_deployment(app, deployment_params),
         {:ok, %Members.Actor{} = actor} <-
           Members.get_or_create_actor(actor_params),
         {:ok, %Install{} = install} <-
           Packages.create_install(deployment, instellar_installation_id),
         :ok <-
           Cache.put(
             {:deployment, compute_signature(deployment.hash),
              instellar_installation_id},
             metadata
           ) do
      case deployment.current_state do
        "created" ->
          Packages.transition_deployment_with(deployment, actor, "prepare")

        "live" ->
          Packages.transition_install_with(install, actor, "validate")

        _ ->
          {:ok, :do_nothing}
      end

      json(conn, :created, %{id: deployment.id, install: %{id: install.id}})
    else
      {:error, %Ecto.Changeset{} = error} ->
        json(conn, :unprocessable_entity, handle_changeset(error))

      {:actor, :not_found} ->
        json(conn, :not_found, %{error: %{message: "actor not found"}})
    end
  end

  post "/:hash/installs/:instellar_installation_id/metadata/events" do
    case conn.body_params do
      %{"event" => %{"name" => "refresh"}} ->
        :ok =
          Cache.delete(
            {:deployment, compute_signature(hash),
             String.to_integer(instellar_installation_id)}
          )

        hash
        |> Install.by_hash_and_installation(instellar_installation_id)
        |> Repo.one()
        |> Repo.preload([:deployment])
        |> case do
          %Install{} = install ->
            Packages.build_install_state(install)

            json(conn, :ok, %{})

          nil ->
            json(conn, :not_found, %{})
        end

      %{"event" => %{"name" => "delete"}} ->
        :ok =
          Cache.delete(
            {:deployment, compute_signature(hash),
             String.to_integer(instellar_installation_id)}
          )

        json(conn, :ok, %{})

      _ ->
        json(conn, :unprocessable_entity, %{
          error: %{message: "event not supported"}
        })
    end
  end

  post "/:hash/installs/:instellar_installation_id/events" do
    %{
      "actor" => actor_params,
      "event" => event_params
    } = conn.body_params

    query = Install.by_hash_and_installation(hash, instellar_installation_id)

    with %Install{} = install <- Repo.one(query),
         {:ok, %Members.Actor{} = actor} <-
           Members.get_or_create_actor(actor_params),
         {:ok, %{event: event}} <-
           Packages.transition_install_with(
             install,
             actor,
             Map.get(event_params, "name"),
             comment: Map.get(event_params, "comment")
           ) do
      json(conn, :created, %{id: event.id, name: event.name})
    else
      {:error, error} ->
        json(conn, :unprocessable_entity, %{error: %{message: error}})

      {:error, error, _} ->
        json(conn, :unprocessable_entity, %{error: %{message: error}})

      {:error, error, _, _} ->
        json(conn, :unprocessable_entity, %{error: %{message: error}})

      {:actor, :not_found} ->
        json(conn, :not_found, %{error: %{message: "actor not found"}})
    end
  end
end
