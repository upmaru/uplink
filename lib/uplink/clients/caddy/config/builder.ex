defmodule Uplink.Clients.Caddy.Config.Builder do
  alias Uplink.Repo

  alias Uplink.Packages
  alias Uplink.Routings

  alias Uplink.Caddy.Config.Hosts
  alias Uplink.Caddy.Config.Port
  alias Uplink.Caddy.Config.Upstreams

  alias Uplink.Clients.Caddy

  alias Uplink.Clients.Caddy.Admin
  alias Uplink.Clients.Caddy.Apps
  alias Uplink.Clients.Caddy.Storage

  def new do
    install_states =
      Packages.Install.latest_by_installation_id(1)
      |> Repo.all()
      |> Repo.preload(deployment: [:app])
      |> Enum.map(&Packages.build_install_state/1)
      |> Enum.filter(&Hosts.routable?/1)

    %{"organization" => %{"storage" => storage_params}} =
      uplink = Uplink.Clients.Instellar.get_self()

    %{
      admin: admin(uplink),
      apps: apps(install_states),
      storage: Storage.parse(storage_params),
      logging: %{
        sink: %{
          writer: %{
            output: "discard"
          }
        },
        logs: %{
          default: %{
            writer: %{
              output: "stdout"
            },
            encoder: %{
              format: "console"
            }
          }
        }
      }
    }
  end

  def admin(uplink) do
    identifiers =
      if instances = Map.get(uplink, "instances") do
        instances
        |> Enum.map(fn i ->
          i["node"]["public_ip"]
        end)
      else
        []
      end

    %{
      identity: %{
        identifiers: identifiers
      }
    }
    |> Admin.parse()
  end

  def apps(install_states) do
    %{
      http: %{
        servers: servers(install_states)
      },
      tls: %{
        automation: %{
          policies: [
            %{
              issuers: build_issuers()
            }
          ]
        }
      }
    }
    |> Apps.parse()
  end

  def servers(installs) do
    %{
      "uplink" => %{
        listen: [":443"],
        listener_wrappers: [
          %{wrapper: "proxy_protocol"},
          %{wrapper: "tls"}
        ],
        routes:
          installs
          |> Enum.flat_map(&build_route/1)
          |> Enum.uniq_by(fn route ->
            path =
              Enum.map(route.match, fn m -> m.path end)
              |> Enum.sort()
              |> Enum.join(":")

            host =
              Enum.map(route.match, fn m -> m.host end)
              |> Enum.sort()
              |> Enum.join(":")

            "#{route.group}_#{host}_#{path}"
          end)
          |> Enum.sort_by(fn route ->
            paths = Enum.flat_map(route.match, fn m -> m.path end)

            if Enum.any?(paths, &(&1 == "*")), do: 1, else: 0
          end),
        logs: %{
          default_logger_name: "default"
        }
      }
    }
  end

  defp build_route(
         %{
           install: %{id: install_id, deployment: %{app: _app}},
           metadata: metadata
         } = _state
       ) do
    main_routing = Map.get(metadata.main_port, :routing)

    main_routing_hosts =
      if main_routing do
        main_routing.hosts
      else
        []
      end

    main_paths =
      if main_routing && main_routing.paths != [] do
        main_routing.paths
      else
        ["*"]
      end

    main_group =
      if main_routing do
        "router_#{main_routing.router_id}"
      else
        "installation_#{metadata.id}"
      end

    proxies =
      if main_routing do
        Routings.list_proxies(main_routing.router_id)
      else
        []
      end

    proxy_routes =
      proxies
      |> Enum.map(fn proxy ->
        %{
          group: main_group,
          match: [
            %{host: proxy.hosts, path: proxy.paths}
          ],
          handle: [
            %{
              handler: "reverse_proxy",
              load_balancing: %{
                selection_policy: %{policy: "least_conn"}
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
              upstreams: [
                %{
                  dial: "#{proxy.target}:#{proxy.port}",
                  max_requests: 100
                }
              ]
            }
            |> maybe_merge_tls(proxy)
          ]
        }
      end)

    main_hosts =
      metadata.hosts
      |> Enum.concat(main_routing_hosts)
      |> Enum.uniq()
      |> Enum.sort()

    main_route = %{
      group: main_group,
      match: [
        %{
          host: main_hosts,
          path: main_paths
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
          upstreams: Upstreams.build(metadata, metadata.main_port, install_id)
        }
      ]
    }

    sub_routes = Port.build(metadata, install_id)

    sub_routes_and_proxies = Enum.concat(sub_routes, proxy_routes)

    [main_route | sub_routes_and_proxies]
  end

  defp build_issuers do
    [
      Caddy.Issuers.ACME.create!(%{
        challenges:
          maybe_merge_dns(%{
            http: %{},
            tls_alpn: %{}
          })
      })
      |> clean_acme_params()
    ]
  end

  defp maybe_merge_tls(params, %{tls: true}) do
    Map.put(params, :transport, %{
      protocol: "http",
      tls: %{}
    })
  end

  defp maybe_merge_tls(params, _), do: params

  defp maybe_merge_dns(params) do
    if cloudflare_token = System.get_env("CLOUDFLARE_DNS_TOKEN") do
      Map.put(params, :dns, %{
        provider:
          Caddy.Issuers.DNS.Cloudflare.create!(%{api_token: cloudflare_token})
      })
    else
      params
    end
  end

  defp clean_acme_params(%Caddy.Issuers.ACME{challenges: challenges} = acme) do
    dns = challenges.dns || %{}

    challenges =
      %{
        "http" => challenges.http,
        "tls-alpn" => challenges.tls_alpn,
        "dns" =>
          dns
          |> Jason.encode!()
          |> Jason.decode!()
          |> Enum.reject(fn {_, v} -> v in ["", [""], nil, 0] end)
          |> Enum.into(%{}),
        "bind_host" => challenges.bind_host
      }
      |> Enum.reject(fn {_, v} -> v in ["", [""], nil, 0] end)
      |> Enum.into(%{})

    acme
    |> Jason.encode!()
    |> Jason.decode!()
    |> Map.put("challenges", challenges)
    |> Enum.reject(fn {_, v} -> v in ["", [""], nil, 0] end)
    |> Enum.into(%{})
  end
end
