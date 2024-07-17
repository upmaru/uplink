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

    project =
      "#{metadata.channel.package.organization.slug}.#{metadata.channel.package.slug}"

    {:ok,
     cluster_members: cluster_members,
     public_key_name: public_key_name,
     project: project}
  end

  setup %{bypass: bypass, cluster_members: cluster_members} do
    Bypass.expect_once(bypass, "GET", "/1.0/cluster/members", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, cluster_members)
    end)

    instances_list = File.read!("test/fixtures/lxd/instances/list/empty.json")

    Bypass.expect_once(bypass, "GET", "/1.0/instances", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, instances_list)
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
    test "when project does not exist", %{
      bypass: bypass,
      install: install,
      actor: actor,
      public_key_name: public_key_name,
      create_instance: create_instance,
      start_instance: start_instance,
      exec_instance: exec_instance,
      wait_for_operation: wait_for_operation,
      wait_with_log: wait_with_log,
      project: project_name
    } do
      instance_slug = "test-02"

      project_not_found =
        File.read!("test/fixtures/lxd/projects/not_found.json")

      Bypass.expect_once(
        bypass,
        "GET",
        "/1.0/projects/#{project_name}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(404, project_not_found)
        end
      )

      create_project = File.read!("test/fixtures/lxd/projects/create.json")

      Bypass.expect_once(
        bypass,
        "POST",
        "/1.0/projects",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, create_project)
        end
      )

      Bypass.expect_once(bypass, "POST", "/1.0/instances", fn conn ->
        assert %{
                 "target" => "ubuntu-s-1vcpu-1gb-sgp1-01",
                 "project" => project
               } = conn.query_params

        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert %{"source" => source} = Jason.decode!(body)

        assert %{"server" => server} = source

        assert server == "https://localhost/spaces/test"

        assert project == project_name

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
          assert %{"timeout" => "180"} = conn.query_params

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
          assert %{"project" => project} = conn.query_params

          assert project == project_name

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
          assert %{"timeout" => "180"} = conn.query_params

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
          assert %{"project" => project} = conn.query_params

          assert project == project_name

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
          assert %{"project" => project} = conn.query_params

          assert project == project_name

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
          assert %{"project" => project} = conn.query_params

          assert project == project_name

          conn
          |> Plug.Conn.resp(200, "")
        end
      )

      Bypass.expect_once(
        bypass,
        "PUT",
        "/1.0/instances/#{instance_slug}/state",
        fn conn ->
          assert %{"project" => project} = conn.query_params

          assert project == project_name

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
          %{"timeout" => "180"} = conn.query_params

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

    test "with matching cluster member", %{
      bypass: bypass,
      install: install,
      actor: actor,
      public_key_name: public_key_name,
      create_instance: create_instance,
      start_instance: start_instance,
      exec_instance: exec_instance,
      wait_for_operation: wait_for_operation,
      wait_with_log: wait_with_log,
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

      Bypass.expect_once(bypass, "POST", "/1.0/instances", fn conn ->
        assert %{"target" => "ubuntu-s-1vcpu-1gb-sgp1-01", "project" => project} =
                 conn.query_params

        assert project == project_name

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
          assert %{"timeout" => "180"} = conn.query_params

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
          assert %{"project" => project} = conn.query_params

          assert project == project_name

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
          assert %{"timeout" => "180"} = conn.query_params

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
          assert %{"project" => project} = conn.query_params

          assert project == project_name

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
          assert %{"project" => project} = conn.query_params

          assert project == project_name

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
          assert %{"project" => project} = conn.query_params

          assert project == project_name

          conn
          |> Plug.Conn.resp(200, "")
        end
      )

      Bypass.expect_once(
        bypass,
        "PUT",
        "/1.0/instances/#{instance_slug}/state",
        fn conn ->
          assert %{"project" => project} = conn.query_params

          assert project == project_name

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
          %{"timeout" => "180"} = conn.query_params

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
      wait_with_log: wait_with_log,
      project: project_name
    } do
      instance_slug = "test-02"

      Bypass.expect_once(bypass, "POST", "/1.0/instances", fn conn ->
        assert %{"target" => "ubuntu-s-1vcpu-1gb-sgp1-01", "project" => project} =
                 conn.query_params

        assert project == project_name

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
          assert %{"timeout" => "180"} = conn.query_params

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
          assert %{"project" => project} = conn.query_params

          assert project == project_name

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
          assert %{"project" => project} = conn.query_params

          assert project == project_name

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
          assert %{"project" => project} = conn.query_params

          assert project == project_name

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
          assert %{"project" => project} = conn.query_params

          assert project == project_name

          conn
          |> Plug.Conn.resp(200, "something went wrong")
        end
      )

      Bypass.expect_once(
        bypass,
        "PUT",
        "/1.0/instances/#{instance_slug}/state",
        fn conn ->
          assert %{"project" => project} = conn.query_params

          assert project == project_name

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
          assert %{"timeout" => "180"} = conn.query_params

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
      actor: actor,
      bypass: bypass,
      project: project_name
    } do
      args = %{
        instance: %{
          slug: instance_slug,
          current_state: "booting",
          node: %{slug: "ubuntu-s-1vcpu-1gb-sgp1-01"}
        },
        install_id: install.id,
        actor_id: actor.id
      }

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

      assert {:ok, %Oban.Job{}} = perform_job(Bootstrap, args)

      args = %{
        instance: Map.merge(args.instance, %{current_state: "failing"}),
        install_id: install.id,
        actor_id: actor.id
      }

      assert_enqueued(worker: Uplink.Packages.Instance.Cleanup, args: args)
    end
  end

  describe "bootstrap instance metadata with package_size" do
    setup [:setup_base_with_package_size]

    setup %{metadata: metadata} do
      size_profile =
        "size.#{metadata.channel.package.organization.slug}.#{metadata.channel.package.slug}.#{metadata.package_size.slug}"

      {:ok, size_profile: size_profile}
    end

    test "when project and size does not exist", %{
      bypass: bypass,
      install: install,
      actor: actor,
      public_key_name: public_key_name,
      create_instance: create_instance,
      start_instance: start_instance,
      exec_instance: exec_instance,
      wait_for_operation: wait_for_operation,
      wait_with_log: wait_with_log,
      project: project_name,
      size_profile: size_profile
    } do
      instance_slug = "test-02"

      project_not_found =
        File.read!("test/fixtures/lxd/projects/not_found.json")

      Bypass.expect_once(
        bypass,
        "GET",
        "/1.0/projects/#{project_name}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(404, project_not_found)
        end
      )

      create_project = File.read!("test/fixtures/lxd/projects/create.json")

      Bypass.expect_once(
        bypass,
        "POST",
        "/1.0/projects",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, create_project)
        end
      )

      size_profile_not_found =
        File.read!("test/fixtures/lxd/profiles/not_found.json")

      Bypass.expect_once(
        bypass,
        "GET",
        "/1.0/profiles/#{size_profile}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(404, size_profile_not_found)
        end
      )

      create_size_profile = File.read!("test/fixtures/lxd/profiles/create.json")

      Bypass.expect_once(
        bypass,
        "POST",
        "/1.0/profiles",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, create_size_profile)
        end
      )

      Bypass.expect_once(bypass, "POST", "/1.0/instances", fn conn ->
        assert %{
                 "target" => "ubuntu-s-1vcpu-1gb-sgp1-01",
                 "project" => project
               } = conn.query_params

        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert %{"source" => source, "profiles" => profiles} =
                 Jason.decode!(body)

        assert size_profile in profiles

        assert %{"server" => server} = source

        assert server == "https://localhost/spaces/test"

        assert project == project_name

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
          assert %{"timeout" => "180"} = conn.query_params

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
          assert %{"project" => project} = conn.query_params

          assert project == project_name

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
          assert %{"timeout" => "180"} = conn.query_params

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
          assert %{"project" => project} = conn.query_params

          assert project == project_name

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
          assert %{"project" => project} = conn.query_params

          assert project == project_name

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
          assert %{"project" => project} = conn.query_params

          assert project == project_name

          conn
          |> Plug.Conn.resp(200, "")
        end
      )

      Bypass.expect_once(
        bypass,
        "PUT",
        "/1.0/instances/#{instance_slug}/state",
        fn conn ->
          assert %{"project" => project} = conn.query_params

          assert project == project_name

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
          %{"timeout" => "180"} = conn.query_params

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
end
