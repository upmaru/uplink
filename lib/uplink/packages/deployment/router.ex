defmodule Uplink.Packages.Deployment.Router do
  use Plug.Router
  use Uplink.Web

  alias Uplink.{
    Members,
    Packages,
    Cache
  }

  alias Packages.{
    Installation,
    Deployment,
    Metadata
  }

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  plug :match

  plug Deployment.Secret

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["application/*"],
    json_decoder: Jason

  plug :dispatch

  post "/" do
    %{
      "actor" => actor_params,
      "installation_id" => installation_id,
      "deployment" => deployment_params
    } = conn.body_params

    with {:ok, %Metadata{} = metadata} <-
           deployment_params
           |> Map.get("metadata")
           |> Packages.parse_metadata(),
         %Members.Actor{} = actor <- Members.get_actor(actor_params),
         %Installation{} = installation <-
           Packages.get_or_create_installation(
             installation_id,
             Metadata.installation_slug(metadata)
           ),
         {:ok, %Deployment{} = deployment} <-
           Packages.create_deployment(installation, deployment_params),
         :ok <-
           Cache.put(
             {:deployment, compute_signature(deployment.hash)},
             metadata
           ),
         {:ok, %{resource: preparing_deployment}} <-
           Packages.transition_deployment_with(deployment, actor, "prepare") do
      json(conn, :created, %{id: preparing_deployment.id})
    else
      {:error, _error} ->
        json(conn, :unprocessable_entity, %{
          error: %{message: "invalid deployment parameters"}
        })

      {:actor, :not_found} ->
        json(conn, :not_found, %{error: %{message: "actor not found"}})
    end
  end
end
