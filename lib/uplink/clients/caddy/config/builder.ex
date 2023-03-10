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
        routes: Enum.map(installs, &build_route/1)
      }
    }
  end

  defp build_route(
         %{install: %{deployment: %{app: _app}}, metadata: metadata} = _state
       ) do
    %{
      match: [%{host: metadata.hosts}],
      handle: [
        %{
          handler: "reverse_proxy",
          load_balancing: %{
            selection_policy: "ip_hash"
          },
          health_checks: %{
            passive: %{
              fail_duration: "10s",
              max_fails: 3,
              unhealthy_request_count: 80,
              unhealthy_status: [500, 501, 502, 503, 504],
              unhealthy_latench: "35s"
            }
          },
          upstreams:
            Enum.map(metadata.instances, fn instance ->
              %{
                dial: "#{instance.slug}:#{metadata.main_port.target}",
                max_requests: 10
              }
            end)
        }
      ]
    }
  end
end
