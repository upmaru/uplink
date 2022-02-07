defmodule Uplink.Packages.Install.ValidateTest do
  use ExUnit.Case
  use Oban.Testing, repo: Uplink.Repo

  alias Uplink.{
    Packages,
    Members,
    Cache
  }

  alias Packages.{
    Metadata,
    Install
  }

  alias Install.Validate

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  @deployment_params %{
    "hash" => "some-hash",
    "archive_url" => "http://localhost/archives/packages.zip",
    "metadata" => %{
      "installation" => %{
        "id" => 1,
        "slug" => "uplink-web",
        "service_port" => 4000,
        "exposed_port" => 49152,
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
      "id" => 8000,
      "package" => %{
        "slug" => "something-1640927800",
        "organization" => %{
          "slug" => "upmaru"
        }
      }
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

    list_profiles = File.read!("test/fixtures/lxd/profiles/list.json")

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

    {:ok,
     install: validating_install,
     deployment: deployment,
     actor: actor,
     bypass: bypass,
     list_profiles: list_profiles}
  end

  describe "when profile does not exist" do
    setup do
      Cache.put(:instances, [])

      create_profile = File.read!("test/fixtures/lxd/profiles/create.json")

      {:ok, create_profile: create_profile}
    end

    test "invokes create profile", %{
      bypass: bypass,
      install: install,
      actor: actor,
      list_profiles: list_profiles,
      create_profile: create_profile
    } do
      Bypass.expect_once(bypass, "GET", "/1.0/profiles", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, list_profiles)
      end)

      Bypass.expect_once(bypass, "POST", "/1.0/profiles", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, create_profile)
      end)

      assert {:ok, %{resource: install}} =
               perform_job(Validate, %{
                 install_id: install.id,
                 actor_id: actor.id
               })

      assert install.current_state == "executing"
    end
  end
end
