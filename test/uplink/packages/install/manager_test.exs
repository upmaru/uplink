defmodule Uplink.Packages.Install.ManagerTest do
  use ExUnit.Case

  alias Uplink.{
    Members,
    Packages,
    Repo
  }

  alias Packages.{
    Metadata,
    Install
  }

  @deployment_params %{
    "hash" => "some-hash",
    "archive_url" => "http://localhost/archives/packages.zip",
    "channel" => "develop",
    "stack" => "alpine/3.14",
    "metadata" => %{
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
          "id" => 1,
          "slug" => "something-1",
          "node" => %{
            "slug" => "some-node"
          }
        }
      ]
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

    test "can transition to executing", %{install: install, actor: actor} do
      {:ok, %{resource: validating_install}} =
        Manager.transition_with(install, actor, "validate")

      assert {:ok, _transition} =
               Manager.transition_with(validating_install, actor, "execute")
    end
  end

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

  describe "build state" do
    alias Install.Manager

    setup %{deployment: deployment} do
      {:ok, %Install{} = install} = Manager.create(deployment, 1)

      {:ok, actor} = Members.create_actor(%{"identifier" => "zacksiri"})

      install = Repo.preload(install, [:deployment])

      Uplink.Cache.flush()

      bypass = Bypass.open()

      Application.put_env(
        :uplink,
        Uplink.Clients.Instellar,
        endpoint: "http://localhost:#{bypass.port}/uplink"
      )

      {:ok, bypass: bypass, install: install, actor: actor}
    end

    test "can build state by fetching from instellar", %{
      bypass: bypass,
      install: install,
      actor: actor
    } do
      Bypass.expect_once(bypass, "GET", "/uplink/installations/1", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(@uplink_installation_state_response)
        )
      end)

      assert %{install: _install, metadata: _metadata, actor: _actor} =
               Manager.build_state(install, actor)
    end
  end
end
