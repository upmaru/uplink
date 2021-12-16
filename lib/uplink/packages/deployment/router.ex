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

    with %Members.Actor{} <- Members.get_actor(actor_params),
         %Installation{} = installation <-
           Packages.get_or_create_installation(installation_id),
         {:ok, %Deployment{} = deployment} <-
           Packages.create_deployment(installation, deployment_params) do
      key_signature = compute_signature(deployment.hash)

      Cache.put({:deployment, key_signature}, deployment.metadata)
      json(conn, :created, %{id: deployment.id})
    else
      {:actor, :not_found} ->
        json(conn, :not_found, %{error: %{message: "actor not found"}})
    end
  end
end
