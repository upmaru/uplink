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

  alias Uplink.Packages.Instance.Install

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

    Cache.put({:install, install.id, "completed"}, [])
    Cache.put({:install, install.id, "executing"}, ["some-instance-01"])

    start_instance = File.read!("test/fixtures/lxd/instances/start.json")
    exec_instance = File.read!("test/fixtures/lxd/instances/exec.json")
    wait_for_operation = File.read!("test/fixtures/lxd/operations/wait.json")

    wait_with_log =
      File.read!("test/fixtures/lxd/operations/wait_with_log.json")

    project =
      "#{metadata.channel.package.organization.slug}.#{metadata.channel.package.slug}"

    {:ok,
     bypass: bypass,
     actor: actor,
     start_instance: start_instance,
     exec_instance: exec_instance,
     wait_for_operation: wait_for_operation,
     wait_with_log: wait_with_log,
     install: executing_install,
     metadata: metadata,
     project: project}
  end

  describe "perform" do
    test "successfully perform install", %{
      bypass: bypass,
      actor: actor,
      start_instance: start_instance,
      exec_instance: exec_instance,
      wait_for_operation: wait_for_operation,
      wait_with_log: wait_with_log,
      install: install,
      project: project_name
    } do
      instance_slug = "test-02"

      project_found = File.read!("test/fixtures/lxd/projects/show.json")

      Bypass.expect_once(
        bypass,
        "GET",
        "/1.0/projects/#{project_name}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, project_found)
        end
      )

      start_instance_params = Jason.decode!(start_instance)
      start_instance_operation_id = start_instance_params["metadata"]["id"]

      Bypass.expect_once(
        bypass,
        "PUT",
        "/1.0/instances/#{instance_slug}/state",
        fn conn ->
          assert %{"project" => project} = conn.query_params

          assert project == project_name

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
          assert %{"project" => project} = conn.query_params

          assert project == project_name

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
          assert %{"project" => project} = conn.query_params

          assert project == project_name

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
          assert %{"project" => project} = conn.query_params

          assert project == project_name

          conn
          |> Plug.Conn.resp(200, "")
        end
      )

      Bypass.expect(
        bypass,
        "POST",
        "/uplink/installations/#{install.instellar_installation_id}/instances/#{instance_slug}/events",
        fn conn ->
          assert {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert {:ok, body} = Jason.decode(body)

          %{"event" => %{"name" => event_name}} = body

          assert event_name in ["complete", "boot"]

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

      assert {:ok, %Oban.Job{worker: worker}} =
               perform_job(Install, %{
                 instance: %{
                   slug: instance_slug,
                   node: %{
                     slug: "ubuntu-s-1vcpu-1gb-sgp1-01"
                   }
                 },
                 install_id: install.id,
                 actor_id: actor.id
               })

      assert worker == "Uplink.Packages.Instance.Finalize"

      assert_enqueued(
        worker: Uplink.Clients.Caddy.Config.Reload,
        args: %{install_id: install.id}
      )
    end
  end

  describe "on error" do
    setup %{
      bypass: bypass,
      project: project_name
    } do
      instance_slug = "test-02"

      Bypass.expect_once(
        bypass,
        "POST",
        "/1.0/instances/#{instance_slug}/exec",
        fn conn ->
          assert %{"project" => project} = conn.query_params

          assert project == project_name

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
          |> Plug.Conn.resp(
            400,
            Jason.encode!(%{"error" => "Instance is not running"})
          )
        end
      )

      {:ok, instance_slug: instance_slug}
    end

    test "should snooze", %{
      instance_slug: instance_slug,
      bypass: bypass,
      install: install,
      actor: actor,
      project: project_name
    } do
      project_found = File.read!("test/fixtures/lxd/projects/show.json")

      Bypass.expect(
        bypass,
        "POST",
        "/uplink/installations/#{install.instellar_installation_id}/instances/#{instance_slug}/events",
        fn conn ->
          assert {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert {:ok, body} = Jason.decode(body)

          %{"event" => %{"name" => event_name}} = body

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

      Bypass.expect_once(
        bypass,
        "GET",
        "/1.0/projects/#{project_name}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, project_found)
        end
      )

      assert {:snooze, 5} =
               perform_job(Install, %{
                 instance: %{
                   slug: instance_slug,
                   node: %{
                     slug: "ubuntu-s-1vcpu-1gb-sgp1-01"
                   }
                 },
                 install_id: install.id,
                 actor_id: actor.id
               })
    end
  end
end
