defmodule Uplink.Scenarios.Deployment do
  alias Uplink.{
    Secret,
    Packages,
    Members,
    Cache
  }

  alias Packages.{
    Metadata
  }

  @deployment_params %{
    "hash" => "some-hash",
    "archive_url" => "http://localhost/archives/packages.zip",
    "stack" => "alpine/3.14",
    "channel" => "develop",
    "metadata" => %{
      "id" => 1,
      "slug" => "uplink-web",
      "main_port" => %{
        "slug" => "web",
        "source" => 49152,
        "target" => 4000,
        "routing" => %{
          "router_id" => 1,
          "paths" => ["/configure*"]
        }
      },
      "ports" => [
        %{
          "slug" => "grpc",
          "source" => 49153,
          "target" => 6000
        }
      ],
      "hosts" => ["something.com"],
      "variables" => [
        %{"key" => "SOMETHING", "value" => "blah"}
      ],
      "channel" => %{
        "slug" => "develop",
        "package" => %{
          "slug" => "something-1640927800",
          "credential" => %{
            "public_key" => "public_key"
          },
          "organization" => %{
            "slug" => "upmaru"
          }
        }
      },
      "instances" => [
        %{
          "id" => 1,
          "slug" => "something-1",
          "node" => %{
            "slug" => "some-node"
          }
        }
      ]
    }
  }

  @deployment_params_with_package_size %{
    "hash" => "some-hash-with-package-size",
    "archive_url" => "http://localhost/archives/packages.zip",
    "stack" => "alpine/3.14",
    "channel" => "develop",
    "metadata" => %{
      "id" => 1,
      "slug" => "uplink-web",
      "package_size" => %{
        "slug" => "medium",
        "allocation" => %{
          "cpu" => 1,
          "cpu_allowance" => "100%",
          "cpu_priority" => 10,
          "memory" => 1,
          "memory_unit" => "GiB",
          "memory_swap" => false,
          "memory_enforce" => "hard"
        }
      },
      "main_port" => %{
        "slug" => "web",
        "source" => 49152,
        "target" => 4000,
        "routing" => %{
          "router_id" => 1,
          "paths" => ["/configure*"]
        }
      },
      "ports" => [
        %{
          "slug" => "grpc",
          "source" => 49153,
          "target" => 6000
        }
      ],
      "hosts" => ["something.com"],
      "variables" => [
        %{"key" => "SOMETHING", "value" => "blah"}
      ],
      "channel" => %{
        "slug" => "develop",
        "package" => %{
          "slug" => "something-1640927800",
          "credential" => %{
            "public_key" => "public_key"
          },
          "organization" => %{
            "slug" => "upmaru"
          }
        }
      },
      "instances" => [
        %{
          "id" => 1,
          "slug" => "something-1",
          "node" => %{
            "slug" => "some-node"
          }
        }
      ]
    }
  }

  def setup_endpoints(_context) do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)

    bypass = Bypass.open()

    Cache.transaction([keys: [:self]], fn ->
      Cache.put(:self, %{
        "credential" => %{
          "endpoint" => "http://localhost:#{bypass.port}"
        },
        "uplink" => %{
          "id" => 1,
          "image_server" => "https://localhost/spaces/test"
        },
        "organization" => %{
          "slug" => "someorg",
          "storage" => %{
            "type" => "s3",
            "host" => "some.host",
            "bucket" => "some-bucket",
            "region" => "sgp1",
            "credential" => %{
              "access_key_id" => "access-key",
              "secret_access_key" => "secret"
            }
          }
        },
        "instances" => [
          %{
            "id" => 1,
            "slug" => "uplink-01",
            "node" => %{
              "id" => 1,
              "slug" => "some-node-01",
              "public_ip" => "127.0.0.1"
            }
          }
        ]
      })
    end)

    Application.put_env(
      :uplink,
      Uplink.Clients.Instellar,
      endpoint: "http://localhost:#{bypass.port}/uplink"
    )

    {:ok, bypass: bypass}
  end

  def setup_base(_context) do
    {:ok, actor} =
      Members.get_or_create_actor(%{
        "identifier" => "zacksiri",
        "provider" => "instellar",
        "id" => "1"
      })

    metadata = Map.get(@deployment_params, "metadata")

    {:ok, metadata} = Packages.parse_metadata(metadata)

    app =
      metadata
      |> Metadata.app_slug()
      |> Packages.get_or_create_app()

    {:ok, deployment} =
      Packages.get_or_create_deployment(app, @deployment_params)

    {:ok, %{resource: preparing_deployment}} =
      Packages.transition_deployment_with(deployment, actor, "prepare")

    {:ok, %{resource: deployment}} =
      Packages.transition_deployment_with(
        preparing_deployment,
        actor,
        "complete"
      )

    {:ok, install} =
      Packages.create_install(deployment, %{
        "installation_id" => 1,
        "deployment" => @deployment_params
      })

    signature = Secret.Signature.compute_signature(deployment.hash)

    Cache.put(
      {:deployment, signature, install.instellar_installation_id},
      metadata
    )

    {:ok, %{resource: validating_install}} =
      Packages.transition_install_with(install, actor, "validate")

    {:ok, %{resource: executing_install}} =
      Packages.transition_install_with(validating_install, actor, "execute")

    {:ok,
     actor: actor,
     metadata: metadata,
     app: app,
     deployment: deployment,
     install: executing_install}
  end

  def setup_base_with_package_size(_context) do
    {:ok, actor} =
      Members.get_or_create_actor(%{
        "identifier" => "zacksiri",
        "provider" => "instellar",
        "id" => "1"
      })

    metadata = Map.get(@deployment_params_with_package_size, "metadata")

    {:ok, metadata} = Packages.parse_metadata(metadata)

    app =
      metadata
      |> Metadata.app_slug()
      |> Packages.get_or_create_app()

    {:ok, deployment} =
      Packages.get_or_create_deployment(
        app,
        @deployment_params_with_package_size
      )

    {:ok, %{resource: preparing_deployment}} =
      Packages.transition_deployment_with(deployment, actor, "prepare")

    {:ok, %{resource: deployment}} =
      Packages.transition_deployment_with(
        preparing_deployment,
        actor,
        "complete"
      )

    {:ok, install} =
      Packages.create_install(deployment, %{
        "installation_id" => 1,
        "deployment" => @deployment_params_with_package_size
      })

    signature = Secret.Signature.compute_signature(deployment.hash)

    Cache.put(
      {:deployment, signature, install.instellar_installation_id},
      metadata
    )

    {:ok, %{resource: validating_install}} =
      Packages.transition_install_with(install, actor, "validate")

    {:ok, %{resource: executing_install}} =
      Packages.transition_install_with(validating_install, actor, "execute")

    {:ok,
     actor: actor,
     metadata: metadata,
     app: app,
     deployment: deployment,
     install: executing_install}
  end
end
