defmodule Uplink.Packages.Instance.Router do
  use Plug.Router
  use Uplink.Web

  alias Uplink.{
    Secret,
    Members,
    Packages
  }

  alias Packages.{
    Instance
  }

  plug :match

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    body_reader: {Uplink.Web.CacheBodyReader, :read_body, []},
    json_decoder: Jason

  plug Secret.VerificationPlug

  plug :dispatch

  post "/bootstrap" do
    %{
      "actor" => actor_params,
      "installation_id" => instellar_installation_id,
      "instance" => instance_params
    } = conn.body_params

    with %Members.Actor{id: actor_id} <- Members.get_actor(actor_params),
         %Packages.Install{id: install_id} <-
           Packages.latest_install(instellar_installation_id) do
      {:ok, %{id: job_id}} =
        %{
          instance: instance_params,
          install_id: install_id,
          actor_id: actor_id
        }
        |> Instance.Bootstrap.new()
        |> Oban.insert()

      json(conn, :created, %{id: job_id})
    else
      {:actor, :not_found} ->
        json(conn, :not_found, %{
          error: %{message: "actor not found"}
        })

      nil ->
        json(conn, :unprocessable_entity, %{
          error: %{message: "install not available, create a deployment first"}
        })
    end
  end
end
