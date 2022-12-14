defmodule Uplink.Clients.Caddy.Config.Builder do
  alias Uplink.{
    Clients,
    Packages,
    Repo
  }

  alias Clients.Caddy
  alias Caddy.Admin
  alias Caddy.Apps

  def new do
    install_states =
      Packages.Install.latest_by_installation_id(1)
      |> Repo.all()
      |> Repo.preload(deployment: [:app])
      |> Enum.map(&Packages.build_install_state/1)
      |> Enum.reject(fn %{metadata: metadata} ->
        metadata.hosts == []
      end)

    %{admin: admin(), apps: apps(install_states)}
  end

  def admin do
    zero_ssl_api_key = Caddy.config(:zero_ssl_api_key)

    %{
      identity: %{
        identifiers: [""],
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
          upstreams:
            Enum.map(metadata.instances, fn instance ->
              %{
                dial: "#{instance.slug}:#{metadata.service_port}",
                max_requests: 10
              }
            end)
        }
      ]
    }
  end
end
