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

  import Ecto.Query, only: [order_by: 2]

  get "/:instellar_installation_id/variables" do
    with :ok <- Firewall.allowed?(conn),
         %Install{} = install <-
           Install
           |> order_by(desc: :inserted_at)
           |> Repo.get_by(instellar_installation_id: instellar_installation_id)
           |> Repo.preload([:deployment]),
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
end
