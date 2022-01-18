defmodule Uplink.Packages.Deployment.PrepareTest do
  use ExUnit.Case, async: true
  use Oban.Testing, repo: Uplink.Repo

  alias Uplink.{
    Cache,
    Packages,
    Members
  }

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
      "metadata" => %{
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

    {:ok, actor} =
      Members.create_actor(%{
        identifier: "zacksiri"
      })

    app = Packages.get_or_create_app(@app_slug)

    {:ok, deployment} =
      Packages.get_or_create_deployment(app, deployment_params)

    {:ok, _installation} = Packages.create_installation(deployment, 1)

    {:ok, _transition} =
      Packages.transition_deployment_with(deployment, actor, "prepare")

    {:ok, actor: actor, deployment: deployment, bypass: bypass}
  end

  test "successfully prepare deployment", %{
    deployment: deployment,
    actor: actor,
    bypass: bypass
  } do
    Cache.delete_all()

    Bypass.expect_once(bypass, "GET", "/archives/packages.zip", fn conn ->
      Plug.Conn.send_file(conn, 200, "test/fixtures/archive/packages.zip")
    end)

    assert {:ok, _transition} =
             perform_job(Prepare, %{
               deployment_id: deployment.id,
               actor_id: actor.id
             })
  end
end
