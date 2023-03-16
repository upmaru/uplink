import Config

database_url = System.get_env("DATABASE_URL")
%URI{host: db_host} = URI.parse(database_url)
cacertfile_path = System.get_env("DATABASE_CERT_PATH") || "/etc/ssl/cert.pem"

config :uplink, Uplink.Repo,
  url: database_url,
  queue_target: 10_000,
  ssl_opts: [
    verify: :verify_peer,
    cacertfile: cacertfile_path,
    server_name_indication: to_charlist(db_host),
    customize_hostname_check: [
      # Our hosting provider uses a wildcard certificate.
      # By default, Erlang does not support wildcard certificates.
      # This function supports validating wildcard hosts
      match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
    ]
  ]

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
          "uplink-#{System.get_env("UPLINK_INSTALLATION_ID")}"
        )
    ]
  ]

config :uplink, Uplink.Secret, System.get_env("UPLINK_SECRET")
