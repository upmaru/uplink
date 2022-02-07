defmodule Uplink.Packages.Install.ManagerTest do
  use ExUnit.Case

  alias Uplink.{
    Members,
    Packages
  }

  alias Packages.{
    Metadata,
    Install
  }

  @deployment_params %{
    "hash" => "some-hash",
    "archive_url" => "http://localhost/archives/packages.zip",
    "stack" => "alpine/3.14",
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
        "credential" => %{
          "public_key" => "public_key"
        },
        "organization" => %{
          "slug" => "upmaru"
        }
      }
    }
  }

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)

    metadata = Map.get(@deployment_params, "metadata")

    {:ok, metadata} = Packages.parse_metadata(metadata)

    app =
      metadata
      |> Metadata.app_slug()
      |> Packages.get_or_create_app()

    {:ok, deployment} =
      Packages.get_or_create_deployment(app, @deployment_params)

    {:ok, deployment: deployment}
  end

  describe "create" do
    alias Install.Manager

    test "return installation", %{deployment: deployment} do
      assert {:ok, %Install{}} = Manager.create(deployment, 1)
    end
  end

  describe "transition_with" do
    alias Install.Manager

    setup %{deployment: deployment} do
      {:ok, %Install{} = install} = Manager.create(deployment, 1)

      {:ok, actor} = Members.create_actor(%{"identifier" => "zacksiri"})

      {:ok, install: install, actor: actor}
    end

    test "can transition state", %{install: install, actor: actor} do
      assert {:ok, _transition} =
               Manager.transition_with(install, actor, "validate")
    end
  end
end
