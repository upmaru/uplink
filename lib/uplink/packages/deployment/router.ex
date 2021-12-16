defmodule Uplink.Packages.Deployment.Router do
  use Plug.Router

  alias Uplink.{
    Members,
    Packages
  }

  alias Packages.{
    Installation,
    Deployment
  }

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
      send_resp(
        conn,
        :created,
        Jason.encode!(%{data: %{deployment: %{id: deployment.id}}})
      )
    else
      {:actor, :not_found} ->
        send_resp(
          conn,
          :not_found,
          Jason.encode!(%{data: %{error: %{message: "actor not found"}}})
        )
    end
  end
end
