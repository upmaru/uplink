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
    Deployment
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

    with %Members.Actor{} = actor <- Members.get_actor(actor_params),
         %Installation{} = installation <-
           Packages.get_or_create_installation(installation_id),
         {:ok, %Deployment{} = deployment} <-
           Packages.create_deployment(installation, deployment_params),
         {:ok, %{resource: pending_deployment}} <-
           Packages.transition_deployment_with(deployment, actor, "pend") do
      key_signature = compute_signature(pending_deployment.hash)

      Cache.put({:deployment, key_signature}, pending_deployment.metadata)
      json(conn, :created, %{id: deployment.id})
    else
      {:actor, :not_found} ->
        json(conn, :not_found, %{error: %{message: "actor not found"}})
    end
  end
end
