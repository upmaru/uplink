import Config

uplink_mode = System.get_env("UPLINK_MODE") || "pro"

config :uplink, Uplink.Data, mode: uplink_mode

if config_env() == :prod do
  config :uplink, Uplink.Clients.Instellar,
    endpoint:
      System.get_env("INSTELLAR_ENDPOINT", "https://web.instellar.app/uplink")

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

if config_env() == :prod and uplink_mode == "pro" do
  database_url = System.get_env("DATABASE_URL")

  %URI{host: db_host} = URI.parse(database_url)

  cacert_pem = System.get_env("DATABASE_CERT_PEM")

  cacert_options =
    if cacert_pem do
      [
        cacerts: [
          cacert_pem
          |> X509.Certificate.from_pem!()
          |> X509.Certificate.to_der()
        ]
      ]
    else
      [cacertfile: System.get_env("DATABASE_CERT_PATH") || "/etc/ssl/cert.pem"]
    end

  config :uplink, Uplink.Repo,
    url: database_url,
    queue_target: 10_000,
    ssl_opts:
      [
        verify: :verify_peer,
        server_name_indication: to_charlist(db_host),
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
      |> Keyword.merge(cacert_options)
end

if config_env() == :prod and uplink_mode == "lite" do
  database_url = Formation.Lxd.Alpine.postgresql_connection_url(scheme: "ecto")

  config :uplink, Uplink.Repo,
    url: database_url,
    pool_size: 2
end
