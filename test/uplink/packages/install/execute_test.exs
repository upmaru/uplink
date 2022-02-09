defmodule Uplink.Packages.Install.ExecuteTest do
  use ExUnit.Case, async: true
  use Oban.Testing, repo: Uplink.Repo

  alias Uplink.{
    Cache,
    Members,
    Packages
  }

  alias Packages.{
    Metadata
  }

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

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

    {:ok, actor} = Members.create_actor(%{identifier: "zacksiri"})

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

    empty_instances = File.read!("test/fixtures/lxd/instances/list/empty.json")

    {:ok,
     install: executing_install,
     actor: actor,
     bypass: bypass,
     empty_instances: empty_instances}
  end

  describe "boostrap instance" do
    alias Uplink.Packages.Install.Execute

    test "choose bootstrap path", %{
      bypass: bypass,
      install: install,
      actor: actor,
      empty_instances: empty_instances
    } do
      Bypass.expect_once(bypass, "GET", "/1.0/instances", fn conn ->
        %{"recursive" => "1"} = conn.query_params

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, empty_instances)
      end)

      assert {:ok, job} =
               perform_job(Execute, %{
                 install_id: install.id,
                 actor_id: actor.id
               })
    end
  end
end
