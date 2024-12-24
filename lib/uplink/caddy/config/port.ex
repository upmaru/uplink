defmodule Uplink.Caddy.Config.Port do
  alias Uplink.Packages.Metadata

  alias Uplink.Caddy.Config.Upstreams

  def build(%Metadata{ports: ports} = metadata, install_id) do
    ports
    |> Enum.map(&build(&1, metadata, install_id))
    |> Enum.reject(&is_nil/1)
  end

  def build(%Metadata.Port{} = port, metadata, install_id) do
    hosts = Enum.map(metadata.hosts, &merge_slug_and_host(&1, port))

    routing = Map.get(port, :routing)

    routing_hosts =
      if routing do
        Enum.map(routing.hosts, &merge_slug_and_host(&1, port))
      else
        []
      end

    hosts =
      hosts
      |> Enum.concat(routing_hosts)
      |> Enum.uniq()
      |> Enum.sort()

    paths =
      if routing && routing.paths != [] do
        routing.paths
      else
        ["*"]
      end

    group =
      if routing,
        do: "router_#{routing.router_id}",
        else: "installation_#{metadata.id}"

    if hosts == [] do
      nil
    else
      %{
        group: group,
        match: [
          %{
            host: hosts,
            path: paths
          }
        ],
        handle: [
          %{
            handler: "reverse_proxy",
            load_balancing: %{
              selection_policy: %{
                policy: "least_conn"
              }
            },
            health_checks: %{
              passive: %{
                fail_duration: "10s",
                max_fails: 3,
                unhealthy_request_count: 80,
                unhealthy_status: [500, 501, 502, 503, 504],
                unhealthy_latency: "30s"
              }
            },
            upstreams: Upstreams.build(metadata, port, install_id)
          }
        ]
      }
    end
  end

  defp merge_slug_and_host(host, %Metadata.Port{slug: slug}),
    do: slug <> "." <> host
end
