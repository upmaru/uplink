defmodule Uplink.Packages.Archive.Hydrate.ScheduleTest do
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

  test "correctly schedule archive", %{archive: archive} do
    bot = Members.get_bot!()

    assert :ok == perform_job(Archive.Hydrate.Schedule, %{})

    assert_enqueued(
      worker: Archive.Hydrate,
      args: %{archive_id: archive.id, actor_id: bot.id}
    )
  end
end
