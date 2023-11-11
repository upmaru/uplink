defmodule Uplink.Packages.Deployment.PrepareTest do
  use ExUnit.Case
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
      Members.get_or_create_actor(%{
        "identifier" => "zacksiri",
        "provider" => "instellar",
        "id" => "1"
      })

    app = Packages.get_or_create_app(@app_slug)

    {:ok, deployment} =
      Packages.get_or_create_deployment(app, deployment_params)

    {:ok, _installation} = Packages.create_install(deployment, 1)

    {:ok, %{resource: deployment}} =
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

  describe "already live" do
    setup %{deployment: deployment, actor: actor} do
      {:ok, %{resource: deployment}} =
        Packages.transition_deployment_with(deployment, actor, "complete")

      {:ok, deployment: deployment}
    end

    test "dont prepare again", %{deployment: deployment, actor: actor} do
      assert {:ok, :already_live} =
               perform_job(Prepare, %{
                 deployment_id: deployment.id,
                 actor_id: actor.id
               })
    end
  end
end
