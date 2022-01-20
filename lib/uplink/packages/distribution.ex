defmodule Uplink.Packages.Distribution do
  use Plug.Builder
  plug Plug.Logger

  alias Uplink.{
    Clients,
    Packages
  }
  
  alias Clients.LXD
  alias Packages.Deployment

  # plug :validate

  plug :serve_or_proxy

  # TODO move this into serve_or_proxy
  # plug Plug.Static,
  #   at: "/",
  #   from: "tmp/deployments"

  plug :respond
  
  import Ecto.Query, only: [where: 3, join: 3, preload: 2, limit: 2]

  defp validate(conn, _opts) do
    case LXD.network_leases() do
      leases when is_list(leases) ->
        ip_addresses =
          Enum.map(leases, fn lease ->
            lease.address
          end)

        detected_ip_address =
          conn.remote_ip
          |> :inet.ntoa()
          |> to_string()

        if detected_ip_address in ip_addresses do
          conn
        else
          conn
          |> send_resp(:not_allowed, "")
          |> halt()
        end

      {:error, _error} ->
        halt(conn)
    end
  end

  defp serve_or_proxy(conn, _opts) do
    %{"glob" => params} = conn.params
    
    [org, package] = Enum.take(params, 2)
    app_slug = "#{org}/#{package}"
    
    Deployment
    |> join(:inner, [d], a in assoc(d, :app))
    |> where([d, a], 
      a.slug == ^app_slug 
        and d.current_state == ^"live"
    )
    |> preload([:archive])
    |> limit(1)
    |> Repo.one()
    |> case do
      %Deployment{archive: archive} ->
      
      nil ->
        conn
        |> send_resp(:not_found, "")
        |> halt()
    end
      
      
      
    IO.inspect(conn)
  end

  defp respond(conn, _opts),
    do: send_resp(conn)
end
