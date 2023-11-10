defmodule Uplink.Clients.Caddy.Config.ReloadTest do
  use ExUnit.Case
  use Oban.Testing, repo: Uplink.Repo

  alias Uplink.{
    Repo,
    Cache,
    Members,
    Packages
  }

  alias Packages.{
    Metadata
  }

  alias Uplink.Clients.Caddy.Config

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

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
        "source" => 49153,
        "target" => 4000
      },
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

  @uplink_installation_state_response %{
    "data" => %{
      "attributes" => %{
        "id" => 1,
        "slug" => "uplink-web",
        "main_port" => %{
          "slug" => "web",
          "source" => 49142,
          "target" => 4000
        },
        "variables" => [
          %{"key" => "SOMETHING", "value" => "somevalue"}
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
  }

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)

    bypass = Bypass.open()

    Cache.put(:self, %{
      "credential" => %{
        "endpoint" => "http://localhost:#{bypass.port}"
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

    Application.put_env(
      :uplink,
      Uplink.Clients.Instellar,
      endpoint: "http://localhost:#{bypass.port}/uplink"
    )

    Application.put_env(
      :uplink,
      Uplink.Clients.Caddy,
      endpoint: "http://localhost:#{bypass.port}",
      storage: %{prefix: "uplink"}
    )

    {:ok, _actor} =
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

    {:ok, install} = Packages.create_install(deployment, 1)

    signature = compute_signature(deployment.hash)

    Cache.put(
      {:deployment, signature, install.instellar_installation_id},
      metadata
    )

    {:ok, bypass: bypass, install: install}
  end

  describe "perform" do
    test "reload config", %{bypass: bypass, install: install} do
      Bypass.expect(bypass, "POST", "/load", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, "")
      end)

      Bypass.expect_once(bypass, "GET", "/uplink/installations/1", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(@uplink_installation_state_response)
        )
      end)

      assert :ok ==
               perform_job(Config.Reload, %{install_id: install.id})
    end

    test "mark install completed when refreshing", %{
      bypass: bypass,
      install: install
    } do
      {:ok, install} =
        install
        |> Ecto.Changeset.cast(%{current_state: "refreshing"}, [:current_state])
        |> Repo.update()

      Bypass.expect(bypass, "POST", "/load", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, "")
      end)

      Bypass.expect_once(bypass, "GET", "/uplink/installations/1", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(@uplink_installation_state_response)
        )
      end)

      assert :ok ==
               perform_job(Config.Reload, %{install_id: install.id})

      install = Repo.reload(install)

      assert install.current_state == "completed"
    end
  end
end
