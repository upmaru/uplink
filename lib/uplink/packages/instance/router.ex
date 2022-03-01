defmodule Uplink.Packages.Instance.Router do
  use Plug.Router
  use Uplink.Web

  alias Uplink.{
    Members,
    Packages
  }

  alias Packages.{
    Deployment,
    Instance
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

  impor(Ecto.Query, only: [where: 3, order_by: 2, limit: 1])

  post "/bootstrap" do
    %{
      "actor" => actor_params,
      "installation_id" => instellar_installation_id,
      "instance" => instance_params
    }

    with %Members.Actor{id: actor_id} <- Members.get_actor(actor_params),
         %Packages.Install{id: install_id} <-
           Packages.latest_install(instellar_installation_id) do
      {:ok, %{id: job_id}} =
        %{
          instance: instace_params,
          install_id: install_id,
          actor_id: actor_id
        }
        |> Instance.Bootstrap.new()
        |> Oban.insert()

      json(conn, :created, %{id: job.id})
    else
      nil ->
        json(conn, :unprocessable_entity, %{
          error: %{message: "install not available, create a deployment first"}
        })
    end
  end
end