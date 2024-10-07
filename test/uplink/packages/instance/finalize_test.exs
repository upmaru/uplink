defmodule Uplink.Packages.Instance.FinalizeTest do
  use ExUnit.Case
  use Oban.Testing, repo: Uplink.Repo

  alias Uplink.Cache
  alias Uplink.Members

  alias Uplink.Packages
  alias Uplink.Packages.Metadata

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

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)

    bypass = Bypass.open()

    Cache.put(:self, %{
      "credential" => %{
        "endpoint" => "http://localhost:#{bypass.port}"
      }
    })

    Application.put_env(
      :uplink,
      Uplink.Clients.Instellar,
      endpoint: "http://localhost:#{bypass.port}/uplink"
    )

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

    {:ok, install} =
      Packages.create_install(deployment, %{
        "installation_id" => 1,
        "deployment" => @deployment_params
      })

    {:ok, bypass: bypass, install: install, actor: actor}
  end

  describe "perform" do
    alias Uplink.Packages.Instance.Finalize

    test "calls instellar to mark instance complete", %{
      bypass: bypass,
      install: install,
      actor: actor
    } do
      instance_slug = "some-instance-01"

      Bypass.expect(
        bypass,
        "POST",
        "/uplink/installations/#{install.instellar_installation_id}/instances/#{instance_slug}/events",
        fn conn ->
          assert {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert {:ok, body} = Jason.decode(body)

          %{"event" => %{"name" => event_name, "parameters" => %{"hash" => hash}}} = body

          assert hash == "some-hash"

          assert event_name in ["complete"]

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(
            201,
            Jason.encode!(%{
              "data" => %{"attributes" => %{"id" => 1, "name" => event_name}}
            })
          )
        end
      )

      assert {:ok, %{"id" => 1, "name" => "complete"}} =
               perform_job(
                 Finalize,
                 %{
                   "instance" => %{"slug" => instance_slug},
                   "comment" => "all good!",
                   "install_id" => install.id,
                   "actor_id" => actor.id
                 }
               )
    end
  end
end
