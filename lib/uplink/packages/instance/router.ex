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

  @action_mappings %{
    "bootstrap" => Instance.Bootstrap,
    "cleanup" => Instance.Cleanup,
    "upgrade" => Instance.Upgrade
  }

  post "/:action" do
    %{
      "actor" => actor_params,
      "installation_id" => instellar_installation_id,
      "instance" => instance_params
    } = conn.body_params

    with module when is_atom(module) <- get_module(action),
         {:ok, %Members.Actor{id: actor_id}} <-
           Members.get_or_create_actor(actor_params),
         %Packages.Install{id: install_id} <-
           Packages.latest_install(instellar_installation_id) do
      {:ok, %{id: job_id}} =
        %{
          instance: instance_params,
          install_id: install_id,
          actor_id: actor_id
        }
        |> module.new()
        |> Oban.insert()

      json(conn, :created, %{id: job_id})
    else
      {:action, :not_found} ->
        json(conn, :not_found, %{
          error: %{message: "action not found"}
        })

      {:actor, :not_found} ->
        json(conn, :not_found, %{
          error: %{message: "actor not found"}
        })

      nil ->
        json(conn, :not_found, %{
          error: %{message: "install not available, create a deployment first"}
        })
    end
  end

  defp get_module(action) do
    Map.get(@action_mappings, action) || {:action, :not_found}
  end
end
