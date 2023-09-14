defmodule Uplink.Clients.Caddy.Config.Builder do
  alias Uplink.{
    Clients,
    Packages,
    Repo
  }

  alias Clients.Caddy
  alias Caddy.Admin
  alias Caddy.Apps
  alias Caddy.Storage

  def new do
    install_states =
      Packages.Install.latest_by_installation_id(1)
      |> Repo.all()
      |> Repo.preload(deployment: [:app])
      |> Enum.map(&Packages.build_install_state/1)
      |> Enum.reject(fn %{metadata: metadata} ->
        metadata.hosts == [] || is_nil(metadata.main_port)
      end)

    %{"organization" => %{"storage" => storage_params} = organization} =
      Uplink.Clients.Instellar.get_self()

    %{
      admin: admin(organization),
      apps: apps(install_states),
      storage: Storage.parse(storage_params)
    }
  end

  def admin(%{"slug" => slug}) do
    zero_ssl_api_key = Caddy.config(:zero_ssl_api_key)

    %{
      identity: %{
        identifiers: ["uplink", slug],
        issuers: [
          %{module: "zerossl", api_key: zero_ssl_api_key}
        ]
      }
    }
    |> Admin.parse()
  end

  def apps(install_states) do
    %{
      http: %{
        servers: servers(install_states)
      }
    }
    |> Apps.parse()
  end

  def servers(installs) do
    %{
      "uplink" => %{
        listen: [":443"],
        routes:
          Enum.map(installs, &build_route/1)
          |> List.flatten()
      }
    }
  end

  defp build_route(
         %{install: %{deployment: %{app: _app}}, metadata: metadata} = _state
       ) do
    main_route = %{
      group: "installation_#{metadata.id}",
      match: [%{host: metadata.hosts}],
      handle: [
        %{
          handler: "reverse_proxy",
          load_balancing: %{
            selection_policy: %{
              policy: "ip_hash"
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
          upstreams:
            Enum.map(metadata.instances, fn instance ->
              %{
                dial: "#{instance.slug}:#{metadata.main_port.target}",
                max_requests: 80
              }
            end)
        }
      ]
    }

    sub_routes =
      metadata.ports
      |> Enum.map(fn port ->
        hosts = Enum.map(metadata.hosts, fn host ->
          port.slug <> "." <> host
        end)

        %{
          group: "installation_#{metadata.id}",
          match: [%{host: hosts}],
          handle: [
            %{
              handler: "reverse_proxy",
              load_balancing: %{
                selection_policy: %{
                  policy: "ip_hash"
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
              upstreams:
                Enum.map(metadata.instances, fn instance ->
                  %{
                    dial: "#{instance.slug}:#{port.target}",
                    max_requests: 80
                  }
                end)
            }
          ]
        }
      end)

    [main_route | sub_routes]
  end
end
