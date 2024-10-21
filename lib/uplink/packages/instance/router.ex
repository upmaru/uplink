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
    "upgrade" => Instance.Upgrade,
    "restart" => Instance.Restart
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
           Packages.latest_install(
             instellar_installation_id,
             Map.get(conn.body_params, "deployment")
           ) do
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
        handle_not_found(conn, action, conn.body_params)
    end
  end

  defp handle_not_found(
         conn,
         action,
         %{
           "actor" => actor_params,
           "installation_id" => instellar_installation_id,
           "instance" => instance_params
         }
       )
       when action in ["cleanup", "restart"] do
    with {:ok, %Members.Actor{id: actor_id}} <-
           Members.get_or_create_actor(actor_params),
         %Packages.Install{id: install_id} <-
           Packages.latest_install(instellar_installation_id, nil) do
      module = get_module(action)

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
      _ ->
        handle_not_found(conn, nil, nil)
    end
  end

  defp handle_not_found(conn, _action, _params) do
    json(conn, :not_found, %{
      error: %{message: "install not available, create a deployment first"}
    })
  end

  defp get_module(action) do
    Map.get(@action_mappings, action) || {:action, :not_found}
  end
end
