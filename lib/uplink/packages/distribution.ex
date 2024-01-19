defmodule Uplink.Packages.Distribution do
  use Plug.Builder
  plug Plug.Logger

  alias Uplink.{
    Internal,
    Packages
  }

  alias Packages.{
    Deployment,
    Archive
  }

  alias Internal.Firewall

  plug :validate

  plug :serve_or_proxy

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

    app_slug
    |> Packages.get_latest_deployment(channel)
    |> case do
      %Deployment{archive: archive} ->
        serve(conn, archive)

      nil ->
        conn
        |> send_resp(:not_found, "")
        |> halt()
    end
  end

  defp serve(conn, %Archive{node: archive_node}) do
    if Atom.to_string(Node.self()) == archive_node do
      static_options =
        Plug.Static.init(
          at: "/",
          from: "tmp/deployments"
        )

      conn
      |> Plug.Static.call(static_options)
    else
      [_app, node_host_name] = String.split(archive_node, "@")
      internal_router_config = Application.get_env(:uplink, Uplink.Internal)
      port = Keyword.get(internal_router_config, :port, 4080)

      upstream =
        ["#{conn.scheme}://", "#{node_host_name}:#{port}", conn.request_path]
        |> Path.join()

      client = Tesla.client([Tesla.Middleware.Logger], Tesla.Adapter.Mint)

      reverse_proxy_options = ReverseProxyPlug.init(upstream: upstream)

      conn
      |> Map.put(:path_info, [])
      |> ReverseProxyPlug.call(reverse_proxy_options)
    end
  end
end
