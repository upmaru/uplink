defmodule Uplink.Packages.Install.Router do
  use Plug.Router
  use Uplink.Web

  alias Uplink.{
    Internal,
    Packages,
    Repo
  }

  alias Internal.Firewall

  alias Packages.{
    Install
  }

  plug :match

  plug Plug.Parsers,
    parsers: [:json],
    json_decoder: Jason

  plug :dispatch

  import Ecto.Query, only: [order_by: 2, where: 3, limit: 2, preload: 2]

  get "/:instellar_installation_id/variables" do
    with :ok <- Firewall.allowed?(conn),
         %Install{} = install <- get_install(instellar_installation_id),
         %{metadata: %{variables: variables}} <-
           Packages.build_install_state(install) do
      json(conn, :ok, %{
        attributes: %{
          variables:
            variables
            |> Enum.map(fn variable ->
              {variable.key, variable.value}
            end)
            |> Enum.into(%{})
        }
      })
    else
      {:error, :forbidden} ->
        json(conn, :forbidden, %{error: %{message: "forbidden"}})

      _ ->
        halt(conn)
    end
  end

  get "/:instellar_installation_id/instances" do
    with :ok <- Firewall.allowed?(conn),
         %Install{} = install <- get_install(instellar_installation_id),
         %{metadata: %{instances: instances}} <-
           Packages.build_install_state(install) do
      json(conn, :ok, %{
        attributes: %{
          instances:
            instances
            |> Enum.map(fn instance -> instance.slug end)
        }
      })
    else
      {:error, :forbidden} ->
        json(conn, :forbidden, %{error: %{message: "forbidden"}})

      _ ->
        halt(conn)
    end
  end

  defp get_install(instellar_installation_id) do
    Install
    |> order_by(desc: :inserted_at)
    |> preload([:deployment])
    |> where(
      [i],
      i.instellar_installation_id == ^instellar_installation_id
    )
    |> limit(1)
    |> Repo.one()
  end
end
