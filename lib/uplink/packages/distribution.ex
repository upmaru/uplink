defmodule Uplink.Packages.Distribution do
  use Plug.Builder
  plug Plug.Logger

  alias Uplink.{
    Internal,
    Packages,
    Repo
  }

  alias Packages.{
    Deployment,
    Archive
  }

  alias Internal.Firewall

  plug :validate

  plug :serve_or_proxy

  plug :respond

  import Ecto.Query,
    only: [where: 3, join: 4, preload: 2, limit: 2, order_by: 3]

  defp validate(conn, _opts) do
    case Firewall.allowed?(conn) do
      :ok ->
        conn

      {:error, :forbidden} ->
        conn
        |> send_resp(:forbidden, "")
        |> halt()

      _ ->
        halt(conn)
    end
  end

  defp serve_or_proxy(conn, _opts) do
    %{"glob" => params} = conn.params

    [channel, org, package] = Enum.take(params, 3)
    app_slug = "#{org}/#{package}"

    Deployment
    |> join(:inner, [d], app in assoc(d, :app))
    |> where(
      [d, app],
      app.slug == ^app_slug and
        d.channel == ^channel and
        d.current_state == ^"live"
    )
    |> order_by([d], desc: d.inserted_at)
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
      internal_router_config = Application.get_env(:uplink, Uplink.Internal)
      port = Keyword.get(internal_router_config, :port, 4080)

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
