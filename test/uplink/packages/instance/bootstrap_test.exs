defmodule Uplink.Packages.Instance.BootstrapTest do
  use ExUnit.Case
  use Oban.Testing, repo: Uplink.Repo

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  alias Uplink.{
    Packages,
    Members,
    Cache
  }

  alias Packages.{
    Instance,
    Metadata
  }

  @deployment_params %{
    "hash" => "some-hash",
    "archive_url" => "http://localhost/archives/packages.zip",
    "stack" => "alpine/3.14",
    "channel" => "develop",
    "metadata" => %{
      "installation" => %{
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
      "id" => 8000
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

    cluster_members = File.read!("test/fixtures/lxd/cluster/members/list.json")

    {:ok,
     install: executing_install,
     bypass: bypass,
     actor: actor,
     cluster_members: cluster_members}
  end

  describe "bootstrap instance" do
    alias Instance.Bootstrap

    setup %{bypass: bypass, cluster_members: cluster_members} do
      Bypass.expect_once(bypass, "GET", "/1.0/cluster/members", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, cluster_members)
      end)

      Cache.delete(:cluster_members)

      create_instance = File.read!("test/fixtures/lxd/instances/create.json")

      wait_for_operation = File.read!("test/fixtures/lxd/operations/wait.json")
      
      wait_with_log = File.read!("test/fixtures/lxd/operations/wait_with_log.json")

      start_instance = File.read!("test/fixtures/lxd/instances/start.json")

      exec_instance = File.read!("test/fixtures/lxd/instances/exec.json")

      {:ok,
       create_instance: create_instance,
       wait_for_operation: wait_for_operation,
       wait_with_log: wait_with_log,
       start_instance: start_instance,
       exec_instance: exec_instance}
    end

    test "no matching cluster member", %{
      install: install,
      actor: actor
    } do
      assert {:ok, %{resource: install}} =
               perform_job(Bootstrap, %{
                 instance: %{slug: "something-1", node: %{slug: "some-node-01"}},
                 install_id: install.id,
                 actor_id: actor.id
               })

      assert install.current_state == "failed"
    end

    test "with matching cluster member", %{
      bypass: bypass,
      install: install,
      actor: actor,
      create_instance: create_instance,
      start_instance: start_instance,
      exec_instance: exec_instance,
      wait_for_operation: wait_for_operation
    } do
      instance_slug = "test-02"

      Bypass.expect_once(bypass, "POST", "/1.0/instances", fn conn ->
        assert %{"target" => "ubuntu-s-1vcpu-1gb-sgp1-01"} = conn.query_params

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, create_instance)
      end)

      create_instance_params = Jason.decode!(create_instance)
      create_instance_operation_id = create_instance_params["metadata"]["id"]

      Bypass.expect_once(
        bypass,
        "GET",
        "/1.0/operations/#{create_instance_operation_id}/wait",
        fn conn ->
          assert %{"timeout" => "60"} = conn.query_params

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, wait_for_operation)
        end
      )

      Bypass.expect_once(
        bypass,
        "PUT",
        "/1.0/instances/#{instance_slug}/state",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, start_instance)
        end
      )

      start_instance_params = Jason.decode!(start_instance)
      start_instance_operation_id = start_instance_params["metadata"]["id"]

      Bypass.expect_once(
        bypass,
        "GET",
        "/1.0/operations/#{start_instance_operation_id}/wait",
        fn conn ->
          assert %{"timeout" => "60"} = conn.query_params

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, wait_for_operation)
        end
      )

      Bypass.expect(
        bypass,
        "POST",
        "/1.0/instances/#{instance_slug}/exec",
        fn conn ->
          assert {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert {:ok, %{"command" => command}} = Jason.decode(body)

          assert command in [
                   [
                     "/bin/sh",
                     "-c",
                     "echo 'public_key' > /etc/apk/keys/pakman.rsa.pub\n"
                   ],
                   ["/bin/sh", "-c", "cat /etc/apk/repositories\n"],
                   [
                     "/bin/sh",
                     "-c",
                     "echo http://:4040/distribution/develop/upmaru/something-1640927800 >> /etc/apk/repositories\n"
                   ]
                 ]

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, exec_instance)
        end
      )

      setup_public_key_params = Jason.decode!(exec_instance)
      setup_public_key_operation_id = setup_public_key_params["metadata"]["id"]

      Bypass.expect_once(
        bypass,
        "GET",
        "/1.0/operations/#{setup_public_key_operation_id}/wait",
        fn conn ->
          %{"timeout" => "60"} = conn.query_params
          
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, wait_for_operation)
        end
      )

      assert {:ok, %{resource: install}} =
               perform_job(Bootstrap, %{
                 instance: %{
                   slug: instance_slug,
                   node: %{slug: "ubuntu-s-1vcpu-1gb-sgp1-01"}
                 },
                 install_id: install.id,
                 actor_id: actor.id
               })
    end
  end
end
