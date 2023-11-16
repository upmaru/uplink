defmodule Uplink.Packages.Instance.UpgradeTest do
  use ExUnit.Case
  use Oban.Testing, repo: Uplink.Repo

  import Uplink.Scenarios.Deployment

  alias Uplink.{
    Packages,
    Repo
  }

  setup [:setup_endpoints, :setup_base]

  @first_deployment %{
    "hash" => "some-hash-1",
    "archive_url" => "http://localhost/archives/packages.zip",
    "stack" => "alpine/3.14",
    "channel" => "develop",
    "metadata" => %{
      "id" => 1,
      "slug" => "uplink-web",
      "service_port" => 4000,
      "exposed_port" => 49152,
      "variables" => [
        %{"key" => "SOMETHING", "value" => "blah"}
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

  @second_deployment %{
    "hash" => "some-hash-2",
    "archive_url" => "http://localhost/archives/packages.zip",
    "stack" => "alpine/3.14",
    "channel" => "develop",
    "metadata" => %{
      "id" => 1,
      "slug" => "uplink-web",
      "service_port" => 4000,
      "exposed_port" => 49152,
      "variables" => [
        %{"key" => "SOMETHING", "value" => "blah"}
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
        "current_state" => "synced",
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

  describe "upgrade instance" do
    alias Uplink.Packages.Instance.Upgrade

    setup %{app: app, metadata: metadata} do
      {:ok, first_deployment} =
        Packages.get_or_create_deployment(app, @first_deployment)

      {:ok, second_deployment} =
        Packages.get_or_create_deployment(app, @second_deployment)

      exec_instance = File.read!("test/fixtures/lxd/instances/exec.json")

      {:ok, first_install} = Packages.create_install(first_deployment, 1)

      first_install
      |> Ecto.Changeset.cast(%{current_state: "completed"}, [:current_state])
      |> Repo.update()

      {:ok, second_install} = Packages.create_install(second_deployment, 1)

      second_install
      |> Ecto.Changeset.cast(%{current_state: "completed"}, [:current_state])
      |> Repo.update()

      project =
        "#{metadata.channel.package.organization.slug}.#{metadata.channel.package.slug}"

      wait_with_log =
        File.read!("test/fixtures/lxd/operations/wait_with_log.json")

      {:ok,
       exec_instance: exec_instance,
       wait_with_log: wait_with_log,
       project: project}
    end

    test "perform", %{
      bypass: bypass,
      actor: actor,
      install: install,
      exec_instance: exec_instance,
      wait_with_log: wait_with_log,
      metadata: metadata,
      project: project_name
    } do
      instance_slug = "some-instance-01"

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

      Bypass.expect_once(
        bypass,
        "POST",
        "/1.0/instances/#{instance_slug}/exec",
        fn conn ->
          assert %{"project" => project} = conn.query_params

          assert project == project_name

          assert {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert {:ok, %{"command" => command}} = Jason.decode(body)

          assert command == [
                   "/bin/sh",
                   "-c",
                   "apk update && apk add --upgrade #{metadata.channel.package.slug}\n"
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
            "upgrade complete"
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

          assert %{"event" => %{"name" => event_name}} = body
          assert event_name in ["upgrade", "complete"]

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

      Bypass.expect(bypass, "GET", "/uplink/installations/1", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(@uplink_installation_state_response)
        )
      end)

      assert {:ok, %{event: event}} =
               perform_job(Upgrade, %{
                 instance: %{
                   slug: instance_slug,
                   node: %{slug: "some-node-01"}
                 },
                 install_id: install.id,
                 actor_id: actor.id
               })

      assert event.name == "complete"
    end

    test "on error it enqueue deactivate and bootstrap", %{
      bypass: bypass,
      actor: actor,
      install: install,
      exec_instance: exec_instance,
      wait_with_log: wait_with_log,
      metadata: metadata,
      project: project_name
    } do
      instance_slug = "some-instance-01"

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

      Bypass.expect_once(
        bypass,
        "POST",
        "/1.0/instances/#{instance_slug}/exec",
        fn conn ->
          assert %{"project" => project} = conn.query_params

          assert project == project_name

          assert {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert {:ok, %{"command" => command}} = Jason.decode(body)

          assert command == [
                   "/bin/sh",
                   "-c",
                   "apk update && apk add --upgrade #{metadata.channel.package.slug}\n"
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
            "upgrade complete"
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
          |> Plug.Conn.resp(200, "timeout")
        end
      )

      Bypass.expect(
        bypass,
        "POST",
        "/uplink/installations/#{install.instellar_installation_id}/instances/#{instance_slug}/events",
        fn conn ->
          assert {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert {:ok, body} = Jason.decode(body)

          assert %{"event" => %{"name" => event_name}} = body
          assert event_name == "upgrade"

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

      assert {:ok, job} =
               perform_job(Upgrade, %{
                 instance: %{
                   slug: instance_slug,
                   node: %{slug: "some-node-01"}
                 },
                 install_id: install.id,
                 actor_id: actor.id
               })

      assert %Oban.Job{args: args} = job
      assert Map.get(args, "mode") == "deactivate_and_boot"
    end

    test "on fail to retrieve pid error it schedules clean up", %{
      bypass: bypass,
      actor: actor,
      install: install,
      exec_instance: exec_instance,
      metadata: metadata,
      project: project_name
    } do
      instance_slug = "some-instance-01"

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

      Bypass.expect_once(
        bypass,
        "POST",
        "/1.0/instances/#{instance_slug}/exec",
        fn conn ->
          assert %{"project" => project} = conn.query_params

          assert project == project_name

          assert {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert {:ok, %{"command" => command}} = Jason.decode(body)

          assert command == [
                   "/bin/sh",
                   "-c",
                   "apk update && apk add --upgrade #{metadata.channel.package.slug}\n"
                 ]

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, exec_instance)
        end
      )

      exec_instance_params = Jason.decode!(exec_instance)
      exec_instance_operation_id = exec_instance_params["metadata"]["id"]

      pid_error = File.read!("test/fixtures/lxd/operations/pid_error.json")

      Bypass.expect(
        bypass,
        "GET",
        "/1.0/operations/#{exec_instance_operation_id}/wait",
        fn conn ->
          assert %{"timeout" => "120"} = conn.query_params

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, pid_error)
        end
      )

      Bypass.expect(
        bypass,
        "POST",
        "/uplink/installations/#{install.instellar_installation_id}/instances/#{instance_slug}/events",
        fn conn ->
          assert {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert {:ok, body} = Jason.decode(body)

          assert %{"event" => %{"name" => event_name}} = body
          assert event_name == "upgrade"

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

      assert {:ok, job} =
               perform_job(Upgrade, %{
                 instance: %{
                   slug: instance_slug,
                   node: %{slug: "some-node-01"}
                 },
                 install_id: install.id,
                 actor_id: actor.id
               })

      assert %Oban.Job{args: args} = job
      assert Map.get(args, "mode") == "cleanup"
    end
  end
end
