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
    installs = 
      Packages.Install.latest_by_installation_id(1)
      |> Repo.preload([deployment: [:app]])

    %{admin: admin(), apps: apps(installs)}
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

  def apps(installs) do
    %{
      http: %{
        servers: servers(installs)
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
  
  defp build_route(%{deployment: %{app: app}} = install) do
    %{metadata: metadata} = Packages.build_install_state(install)
  end
end
