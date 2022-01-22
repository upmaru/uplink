defmodule Uplink.Packages.Distribution do
  use Plug.Builder
  plug Plug.Logger

  alias Uplink.{
    Clients,
    Packages,
    Repo
  }

  alias Clients.LXD

  alias Packages.{
    Deployment,
    Archive
  }

  plug :validate

  plug :serve_or_proxy

  plug :respond

  import Ecto.Query,
    only: [where: 3, join: 4, preload: 2, limit: 2]

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
          |> send_resp(:forbidden, "")
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
    |> join(:inner, [d], app in assoc(d, :app))
    |> where(
      [d, app],
      app.slug == ^app_slug and
        d.current_state == ^"live"
    )
    |> preload([:archive])
    |> limit(1)
    |> Repo.one()
    |> case do
      %Deployment{archive: archive} ->
        serve(conn, archive)

      nil ->
        conn
        |> send_resp(:not_found, "")
        |> halt()
    end
  end

  defp serve(conn, %Archive{node: node}) do
    if Atom.to_string(Node.self()) == node do
      static_options =
        Plug.Static.init(
          at: "/",
          from: "tmp/deployments"
        )

      conn
      |> Plug.Static.call(static_options)
    else
      [_app, node_host_name] = String.split(node, "@")
      router_config = Application.get_env(:uplink, Uplink.Router)
      port = Keyword.get(router_config, :port, 4040)

      upstream =
        ["#{conn.scheme}://", "#{node_host_name}:#{port}", conn.request_path]
        |> Path.join()

      reverse_proxy_options = ReverseProxyPlug.init(upstream: upstream)

      conn
      |> Map.put(:path_info, [])
      |> ReverseProxyPlug.call(reverse_proxy_options)
    end
  end

  defp respond(conn, _opts),
    do: send_resp(conn)
end
