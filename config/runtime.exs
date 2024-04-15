import Config

uplink_mode = System.get_env("UPLINK_MODE") || "pro"
package_name = System.get_env("INSTELLAR_PACKAGE_NAME")
org_name = System.get_env("INSTELLAR_PACKAGE_ORGANIZATION_NAME")

project_name =
  if org_name && package_name do
    "#{org_name}.#{package_name}"
  else
    "default"
  end

instance_concurrency =
  System.schedulers_online()
  |> div(2)
  |> max(1)

instance_operation_concurrency =
  System.get_env("INSTANCE_OPERATION_CONCURRENCY", "#{instance_concurrency}")
  |> String.to_integer()

config :uplink, Oban,
  queues: [
    install: 1,
    deployment: 1,
    instance: instance_operation_concurrency,
    caddy: 1,
    components: 1
  ]

config :uplink, Uplink.Data,
  mode: uplink_mode,
  project: project_name

config :uplink, :lxd, timeout: System.get_env("LXD_CLIENT_TIMEOUT", "180")

config :uplink, :polar, endpoint: System.get_env("POLAR_ENDPOINT")

if config_env() == :prod do
  config :uplink, Uplink.Clients.Instellar,
    endpoint: System.get_env("INSTELLAR_ENDPOINT", "https://opsmaru.com/uplink")

  installation_id =
    System.get_env("INSTELLAR_INSTALLATION_ID") ||
      System.get_env("UPLINK_INSTALLATION_ID")

  config :uplink, Uplink.Clients.Caddy,
    endpoint: System.get_env("CADDY_ADMIN_ENDPOINT", "http://localhost:2019"),
    zero_ssl_api_key: System.get_env("ZERO_SSL_API_KEY", ""),
    storage: %{
      prefix:
        System.get_env(
          "CADDY_STORAGE_PREFIX",
          "uplink-#{installation_id}"
        )
    }

  config :uplink, Uplink.Cluster, installation_id: installation_id

  config :libcluster,
    topologies: [
      uplink: [
        strategy: Uplink.Clustering.LXD,
        app_name: System.get_env("UPLINK_APP_NAME", "uplink"),
        lxd_profile_name:
          System.get_env(
            "LXD_PROFILE_NAME",
            "uplink-#{installation_id}"
          )
      ]
    ]

  config :uplink, Uplink.Secret, System.get_env("UPLINK_SECRET")
end

if config_env() == :prod and uplink_mode == "lite" do
  database_url = Formation.Lxd.Alpine.postgresql_connection_url(scheme: "ecto")

  config :uplink, Uplink.Repo,
    url: database_url,
    pool_size: 2
end
