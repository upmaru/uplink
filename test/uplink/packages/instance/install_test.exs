defmodule Uplink.Packages.Instance.InstallTest do
  use ExUnit.Case
  use Oban.Testing, repo: Uplink.Repo

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  alias Uplink.{
    Cache,
    Members,
    Packages
  }

  alias Packages.{
    Metadata
  }

  @deployment_params %{
    "hash" => "some-hash",
    "archive_url" => "http://localhost/archives/packages.zip",
    "stack" => "alpine/3.14",
    "channel" => "develop",
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
      Members.create_actor(%{
        identifier: "zacksiri"
      })

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

    start_instance = File.read!("test/fixtures/lxd/instances/start.json")
    exec_instance = File.read!("test/fixtures/lxd/instances/exec.json")
    wait_for_operation = File.read!("test/fixtures/lxd/operations/wait.json")

    wait_with_log =
      File.read!("test/fixtures/lxd/operations/wait_with_log.json")

    {:ok,
     bypass: bypass,
     start_instance: start_instance,
     exec_instance: exec_instance,
     wait_for_operation: wait_for_operation,
     wait_with_log: wait_with_log,
     install: executing_install}
  end

  describe "perform" do
    alias Uplink.Packages.Instance.Install

    test "successfully perform install", %{
      bypass: bypass,
      start_instance: start_instance,
      exec_instance: exec_instance,
      wait_for_operation: wait_for_operation,
      wait_with_log: wait_with_log,
      install: install
    } do
      instance_slug = "test-02"
      start_instance_params = Jason.decode!(start_instance)
      start_instance_operation_id = start_instance_params["metadata"]["id"]

      Bypass.expect_once(
        bypass,
        "PUT",
        "/1.0/instances/#{instance_slug}/state",
        fn conn ->
          assert {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert {:ok, body} = Jason.decode(body)

          assert body["action"] == "restart"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, start_instance)
        end
      )

      Bypass.expect_once(
        bypass,
        "GET",
        "/1.0/operations/#{start_instance_operation_id}/wait",
        fn conn ->
          assert %{"timeout" => "120"} = conn.query_params

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, wait_for_operation)
        end
      )

      Bypass.expect_once(
        bypass,
        "POST",
        "/1.0/instances/#{instance_slug}/exec",
        fn conn ->
          assert {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert {:ok, %{"command" => command}} = Jason.decode(body)

          assert command ==
                   [
                     "/bin/sh",
                     "-c",
                     "apk update && apk add something-1640927800\n"
                   ]

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, exec_instance)
        end
      )

      exec_instance_params = Jason.decode!(exec_instance)
      exec_instance_operation_id = exec_instance_params["metadata"]["id"]

      Bypass.expect_once(
        bypass,
        "GET",
        "/1.0/operations/#{exec_instance_operation_id}/wait",
        fn conn ->
          assert %{"timeout" => "120"} = conn.query_params

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, wait_with_log)
        end
      )

      Bypass.expect_once(
        bypass,
        "GET",
        "/1.0/instances/#{instance_slug}/logs/stdout.log",
        fn conn ->
          conn
          |> Plug.Conn.resp(
            200,
            "package installed"
          )
        end
      )

      Bypass.expect_once(
        bypass,
        "GET",
        "/1.0/instances/#{instance_slug}/logs/stderr.log",
        fn conn ->
          conn
          |> Plug.Conn.resp(200, "")
        end
      )

      Bypass.expect_once(
        bypass,
        "POST",
        "/uplink/installations/#{install.instellar_installation_id}/instances/#{instance_slug}/events",
        fn conn ->
          assert {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert {:ok, body} = Jason.decode(body)

          %{"event" => %{"name" => "complete" = event_name}} = body

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

      assert {:ok, %{"id" => _id}} =
               perform_job(Install, %{
                 formation_instance: %{
                   "repositories" => [
                     %{
                       "url" =>
                         "http://:4080/distribution/develop/upmaru/something-1640927800",
                       "public_key_name" => "something",
                       "public_key" => "public_key"
                     }
                   ],
                   "packages" => [%{"slug" => "something-1640927800"}],
                   "slug" => instance_slug
                 },
                 install_id: install.id
               })
    end
  end
end
