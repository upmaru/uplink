defmodule Uplink.Packages.Deployment.Router do
  use Plug.Router
  use Uplink.Web

  alias Uplink.{
    Secret,
    Members,
    Packages,
    Cache
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
         %Members.Actor{} = actor <- Members.get_actor(actor_params),
         {:ok, %Install{} = _install} <-
           Packages.create_install(deployment, instellar_installation_id),
         :ok <-
           Cache.put(
             {:deployment, compute_signature(deployment.hash),
              instellar_installation_id},
             metadata
           ) do
      if deployment.current_state == "created" do
        Packages.transition_deployment_with(deployment, actor, "prepare")
      end

      json(conn, :created, %{id: deployment.id})
    else
      {:error, %Ecto.Changeset{} = error} ->
        json(conn, :unprocessable_entity, handle_changeset(error))

      {:actor, :not_found} ->
        json(conn, :not_found, %{error: %{message: "actor not found"}})
    end
  end
end
