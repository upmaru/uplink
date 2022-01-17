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

    Application.put_env(
      :uplink,
      Uplink.Clients.Instellar,
      endpoint: "http://localhost:#{bypass.port}/uplink"
    )

    {:ok, actor} =
      Members.create_actor(%{
        identifier: "zacksiri"
      })

    installation = Packages.get_or_create_installation(1, "upmaru/uplink")

    {:ok, deployment} =
      Packages.create_deployment(installation, deployment_params)

    {:ok, _transition} =
      Packages.transition_deployment_with(deployment, actor, "prepare")

    {:ok,
     actor: actor,
     deployment_params: deployment_params,
     deployment: deployment,
     bypass: bypass}
  end

  test "successfully prepare deployment", %{
    deployment: deployment,
    deployment_params: deployment_params,
    actor: actor,
    bypass: bypass
  } do
    Cache.delete_all()

    metadata_response = %{
      "data" => %{
        "attributes" => Map.get(deployment_params, "metadata")
      }
    }

    Bypass.expect_once(bypass, "GET", "/uplink/installations/1", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, Jason.encode!(metadata_response))
    end)

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
