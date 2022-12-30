defmodule Uplink.Packages.Archive.HydrateTest do
  use ExUnit.Case, async: true
  use Oban.Testing, repo: Uplink.Repo

  alias Uplink.{
    Cache,
    Packages,
    Members,
    Repo
  }

  alias Packages.Archive

  alias Packages.Deployment.{
    Prepare
  }

  @app_slug "upmaru/something-1640927800"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)

    bypass = Bypass.open()

    deployment_params = %{
      "hash" => "some-hash",
      "archive_url" => "http://localhost:#{bypass.port}/archives/packages.zip",
      "stack" => "alpine/3.14",
      "channel" => "develop",
      "metadata" => %{
        "installation" => %{
          "id" => 1,
          "slug" => "uplink-web",
          "service_port" => 4000,
          "exposed_port" => 49152,
          "instances" => [
            %{
              "installation_instance_id" => 1,
              "slug" => "something-1"
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

    {:ok, actor} =
      Members.create_actor(%{
        identifier: "zacksiri"
      })

    app = Packages.get_or_create_app(@app_slug)

    {:ok, deployment} =
      Packages.get_or_create_deployment(app, deployment_params)

    {:ok, _installation} = Packages.create_install(deployment, 1)

    {:ok, _transition} =
      Packages.transition_deployment_with(deployment, actor, "prepare")

    Cache.delete_all()

    Bypass.expect_once(bypass, "GET", "/archives/packages.zip", fn conn ->
      Plug.Conn.send_file(conn, 200, "test/fixtures/archive/packages.zip")
    end)

    perform_job(Prepare, %{
      deployment_id: deployment.id,
      actor_id: actor.id
    })

    archive = Repo.get_by(Archive, deployment_id: deployment.id)

    {:ok,
     archive: archive,
     app: app,
     actor: actor,
     deployment: deployment,
     bypass: bypass}
  end

  test "does not hydrate since files already exist", %{
    archive: archive,
    actor: actor
  } do
    assert {:ok, :archive_already_exists} =
             perform_job(Archive.Hydrate, %{
               archive_id: archive.id,
               actor_id: actor.id
             })
  end

  describe "files don't exist" do
    setup %{archive: archive} do
      bypass = Bypass.open()

      Application.put_env(
        :uplink,
        Uplink.Clients.Instellar,
        endpoint: "http://localhost:#{bypass.port}/uplink"
      )

      # we want to spoof the check to pretend like the files don't exist
      # we change the locations of the archive
      locations =
        Enum.map(archive.locations, fn location ->
          Path.join(["archive", location])
        end)

      {:ok, archive} = Packages.update_archive(archive, %{locations: locations})

      {:ok, archive: archive, bypass: bypass}
    end

    test "run fun hydration since files do not exist", %{
      archive: archive,
      bypass: bypass,
      actor: actor
    } do
      Bypass.expect_once(bypass, "GET", "/archives/packages.zip", fn conn ->
        Plug.Conn.send_file(conn, 200, "test/fixtures/archive/packages.zip")
      end)

      Bypass.expect(
        bypass,
        "GET",
        "/uplink/installations/1/deployment",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "data" => %{
                "attributes" => %{
                  "archive_url" =>
                    "http://localhost:#{bypass.port}/archives/packages.zip"
                }
              }
            })
          )
        end
      )

      assert {:ok, result} =
               perform_job(Archive.Hydrate, %{
                 archive_id: archive.id,
                 actor_id: actor.id
               })

      assert result.resource.current_state == "live"
    end
  end
end
