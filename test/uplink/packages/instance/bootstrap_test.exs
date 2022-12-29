defmodule Uplink.Packages.Instance.BootstrapTest do
  use ExUnit.Case
  use Oban.Testing, repo: Uplink.Repo

  import Uplink.Scenarios.Deployment

  alias Uplink.Cache

  alias Uplink.Packages.Instance.Bootstrap

  setup [:setup_endpoints, :setup_base]

  setup %{metadata: metadata} do
    cluster_members = File.read!("test/fixtures/lxd/cluster/members/list.json")

    public_key_name =
      Enum.join(
        [
          metadata.channel.package.organization.slug,
          metadata.channel.package.slug
        ],
        "-"
      )

    {:ok, cluster_members: cluster_members, public_key_name: public_key_name}
  end

  setup %{bypass: bypass, cluster_members: cluster_members} do
    Bypass.expect_once(bypass, "GET", "/1.0/cluster/members", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, cluster_members)
    end)

    Cache.delete(:cluster_members)

    create_instance = File.read!("test/fixtures/lxd/instances/create.json")

    wait_for_operation = File.read!("test/fixtures/lxd/operations/wait.json")

    wait_with_log =
      File.read!("test/fixtures/lxd/operations/wait_with_log.json")

    start_instance = File.read!("test/fixtures/lxd/instances/start.json")
    stop_instance = File.read!("test/fixtures/lxd/instances/stop.json")

    exec_instance = File.read!("test/fixtures/lxd/instances/exec.json")

    {:ok,
     create_instance: create_instance,
     wait_for_operation: wait_for_operation,
     wait_with_log: wait_with_log,
     start_instance: start_instance,
     stop_instance: stop_instance,
     exec_instance: exec_instance}
  end

  describe "bootstrap instance" do
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
      public_key_name: public_key_name,
      create_instance: create_instance,
      start_instance: start_instance,
      exec_instance: exec_instance,
      wait_for_operation: wait_for_operation,
      wait_with_log: wait_with_log
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
          assert %{"timeout" => "120"} = conn.query_params

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
          assert %{"timeout" => "120"} = conn.query_params

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, wait_for_operation)
        end
      )

      hostname = System.get_env("HOSTNAME")

      distribution_port =
        Application.get_env(:uplink, Uplink.Internal)
        |> Keyword.get(:port)

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
                     "echo 'public_key' > /etc/apk/keys/#{public_key_name}.rsa.pub\n"
                   ],
                   ["/bin/sh", "-c", "cat /etc/apk/repositories\n"],
                   [
                     "/bin/sh",
                     "-c",
                     "echo -e 'http://#{hostname}:#{distribution_port}/distribution/develop/upmaru/something-1640927800' >> /etc/apk/repositories\n"
                   ]
                 ]

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, exec_instance)
        end
      )

      setup_public_key_params = Jason.decode!(exec_instance)
      setup_public_key_operation_id = setup_public_key_params["metadata"]["id"]

      Bypass.expect(
        bypass,
        "GET",
        "/1.0/operations/#{setup_public_key_operation_id}/wait",
        fn conn ->
          assert %{"timeout" => _timeout} = conn.query_params

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, wait_with_log)
        end
      )

      Bypass.expect(
        bypass,
        "GET",
        "/1.0/instances/#{instance_slug}/logs/stdout.log",
        fn conn ->
          conn
          |> Plug.Conn.resp(
            200,
            "http://#{hostname}:#{distribution_port}/distribution/develop/upmaru/something-1640927800"
          )
        end
      )

      Bypass.expect(
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
        "PUT",
        "/1.0/instances/#{instance_slug}/state",
        fn conn ->
          assert {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert {:ok, body} = Jason.decode(body)

          assert body["action"] == "start"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, start_instance)
        end
      )

      start_instance_key_params = Jason.decode!(start_instance)
      start_instance_operation_id = start_instance_key_params["metadata"]["id"]

      Bypass.expect(
        bypass,
        "GET",
        "/1.0/operations/#{start_instance_operation_id}/wait",
        fn conn ->
          %{"timeout" => "120"} = conn.query_params

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, wait_for_operation)
        end
      )

      Bypass.expect_once(
        bypass,
        "POST",
        "/uplink/installations/#{install.instellar_installation_id}/instances/#{instance_slug}/events",
        fn conn ->
          assert {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert {:ok, body} = Jason.decode(body)

          assert %{"event" => %{"name" => "boot" = event_name}} = body

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
               perform_job(Bootstrap, %{
                 instance: %{
                   slug: instance_slug,
                   node: %{slug: "ubuntu-s-1vcpu-1gb-sgp1-01"}
                 },
                 install_id: install.id,
                 actor_id: actor.id
               })

      assert_enqueued(worker: Uplink.Packages.Instance.Install, args: job.args)
    end
  end

  describe "setup fails" do
    setup %{
      bypass: bypass,
      install: install,
      public_key_name: public_key_name,
      create_instance: create_instance,
      start_instance: start_instance,
      exec_instance: exec_instance,
      wait_for_operation: wait_for_operation,
      wait_with_log: wait_with_log
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
          assert %{"timeout" => "120"} = conn.query_params

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

      hostname = System.get_env("HOSTNAME")

      distribution_port =
        Application.get_env(:uplink, Uplink.Internal)
        |> Keyword.get(:port)

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
                     "echo 'public_key' > /etc/apk/keys/#{public_key_name}.rsa.pub\n"
                   ],
                   ["/bin/sh", "-c", "cat /etc/apk/repositories\n"],
                   [
                     "/bin/sh",
                     "-c",
                     "echo -e 'http://#{hostname}:#{distribution_port}/distribution/develop/upmaru/something-1640927800' >> /etc/apk/repositories\n"
                   ]
                 ]

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, exec_instance)
        end
      )

      setup_public_key_params = Jason.decode!(exec_instance)

      setup_public_key_operation_id = setup_public_key_params["metadata"]["id"]

      Bypass.expect(
        bypass,
        "GET",
        "/1.0/operations/#{setup_public_key_operation_id}/wait",
        fn conn ->
          assert %{"timeout" => _timeout} = conn.query_params

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, wait_with_log)
        end
      )

      Bypass.expect(
        bypass,
        "GET",
        "/1.0/instances/#{instance_slug}/logs/stdout.log",
        fn conn ->
          conn
          |> Plug.Conn.resp(
            200,
            "http://#{hostname}:#{distribution_port}/distribution/develop/upmaru/something-1640927800"
          )
        end
      )

      Bypass.expect(
        bypass,
        "GET",
        "/1.0/instances/#{instance_slug}/logs/stderr.log",
        fn conn ->
          conn
          |> Plug.Conn.resp(200, "something went wrong")
        end
      )

      Bypass.expect_once(
        bypass,
        "PUT",
        "/1.0/instances/#{instance_slug}/state",
        fn conn ->
          assert {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert {:ok, body} = Jason.decode(body)

          assert body["action"] == "start"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, start_instance)
        end
      )

      start_instance_key_params = Jason.decode!(start_instance)

      start_instance_operation_id = start_instance_key_params["metadata"]["id"]

      Bypass.expect(
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

      {:ok, instance_slug: instance_slug}
    end

    test "enqueue cleanup when instance setup fails", %{
      install: install,
      instance_slug: instance_slug,
      actor: actor
    } do
      args = %{
        instance: %{
          slug: instance_slug,
          node: %{slug: "ubuntu-s-1vcpu-1gb-sgp1-01"}
        },
        install_id: install.id,
        actor_id: actor.id
      }

      assert {:ok, %{"id" => _id}} = perform_job(Bootstrap, args)

      assert_enqueued(worker: Uplink.Packages.Instance.Cleanup, args: args)
    end
  end
end
