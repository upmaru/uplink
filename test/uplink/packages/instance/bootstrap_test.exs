defmodule Uplink.Packages.Instance.BootstrapTest do
  use ExUnit.Case
  use Oban.Testing, repo: Uplink.Repo

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  alias Uplink.{
    Packages,
    Members,
    Cache
  }

  alias Packages.{
    Instance,
    Metadata
  }

  @deployment_params %{
    "hash" => "some-hash",
    "archive_url" => "http://localhost/archives/packages.zip",
    "stack" => "alpine/3.14",
    "channel" => "develop",
    "metadata" => %{
      "installation" => %{
        "id" => 1,
        "slug" => "uplink-web",
        "service_port" => 4000,
        "exposed_port" => 49152,
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
            "installation_instance_id" => 1,
            "slug" => "something-1",
            "node" => %{
              "slug" => "some-node"
            }
          }
        ]
      },
      "cluster" => %{
        "credential" => %{
          "certificate" => "cert",
          "endpoint" => "https://127.0.0.1:8443",
          "password" => "somepassword",
          "password_confirmation" => "somepassword",
          "private_key" => "key"
        },
        "organization" => %{
          "slug" => "upmaru"
        }
      },
      "id" => 8000
    }
  }

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)

    bypass = Bypass.open()

    Cache.put(:self, %{
      "credential" => %{
        "endpoint" => "http://localhost:#{bypass.port}"
      }
    })

    {:ok, actor} =
      Members.create_actor(%{
        identifier: "zacksiri"
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

    {:ok, %{resource: validating_install}} =
      Packages.transition_install_with(install, actor, "validate")

    {:ok, %{resource: executing_install}} =
      Packages.transition_install_with(validating_install, actor, "execute")

    cluster_members = File.read!("test/fixtures/lxd/cluster/members/list.json")

    {:ok,
     install: executing_install,
     bypass: bypass,
     actor: actor,
     cluster_members: cluster_members}
  end

  describe "bootstrap instance" do
    alias Instance.Bootstrap

    test "no matching cluster member", %{
      bypass: bypass,
      install: install,
      actor: actor,
      cluster_members: cluster_members
    } do
      Bypass.expect_once(bypass, "GET", "/1.0/cluster/members", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, cluster_members)
      end)

      assert {:ok, %{resource: install}} =
               perform_job(Bootstrap, %{
                 instance: %{slug: "something-1", node: %{slug: "some-node-01"}},
                 install_id: install.id,
                 actor_id: actor.id
               })

      assert install.current_state == "failed"
    end
  end
end
