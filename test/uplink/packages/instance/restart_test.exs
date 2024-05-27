defmodule Uplink.Packages.Instance.RestartTest do
  use ExUnit.Case
  use Oban.Testing, repo: Uplink.Repo

  alias Uplink.Packages.Instance.Restart

  import Uplink.Scenarios.Deployment

  setup [:setup_endpoints, :setup_base]

  setup %{metadata: metadata} do
    start_instance = File.read!("test/fixtures/lxd/instances/start.json")
    stop_instance = File.read!("test/fixtures/lxd/instances/stop.json")
    wait_for_operation = File.read!("test/fixtures/lxd/operations/wait.json")

    project =
      "#{metadata.channel.package.organization.slug}.#{metadata.channel.package.slug}"

    {:ok,
     project: project,
     start_instance: start_instance,
     stop_instance: stop_instance,
     wait_for_operation: wait_for_operation}
  end

  describe "perform" do
    test "successfully restart instance", %{
      bypass: bypass,
      actor: actor,
      install: install,
      project: project_name,
      start_instance: start_instance,
      stop_instance: stop_instance,
      wait_for_operation: wait_for_operation
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

      Bypass.expect(
        bypass,
        "PUT",
        "/1.0/instances/#{instance_slug}/state",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)

          {:ok, %{"action" => action}} = Jason.decode(body)

          assert action in ["stop", "start"]

          assert %{"project" => project} = conn.query_params

          assert project == project_name

          resp = %{
            "start" => start_instance,
            "stop" => stop_instance
          }

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Map.fetch!(resp, action))
        end
      )

      stop_instance_key_params = Jason.decode!(stop_instance)
      stop_instance_operation_id = stop_instance_key_params["metadata"]["id"]

      Bypass.expect_once(
        bypass,
        "GET",
        "/1.0/operations/#{stop_instance_operation_id}/wait",
        fn conn ->
          assert %{"timeout" => "180"} = conn.query_params

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, wait_for_operation)
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

      Bypass.expect(
        bypass,
        "POST",
        "/uplink/installations/#{install.instellar_installation_id}/instances/#{instance_slug}/events",
        fn conn ->
          assert {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert {:ok, body} = Jason.decode(body)

          assert %{"event" => %{"name" => event_name}} = body

          assert event_name in ["restart", "complete"]

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

      assert perform_job(Restart, %{
               instance: %{
                 slug: instance_slug
               },
               install_id: install.id,
               actor_id: actor.id
             })
    end

    test "when instance is stuck", %{
      bypass: bypass,
      actor: actor,
      install: install,
      project: project_name,
      stop_instance: stop_instance,
      wait_for_operation: wait_for_operation
    } do
      wait_for_operation = Jason.decode!(wait_for_operation)

      wait_for_operation_metadata =
        wait_for_operation["metadata"]
        |> Map.put("status_code", 400)
        |> Map.put("err", "Something went wrong")

      wait_for_operation =
        wait_for_operation
        |> Map.put("status_code", 400)
        |> Map.put("metadata", wait_for_operation_metadata)
        |> Jason.encode!()

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

      Bypass.expect(
        bypass,
        "PUT",
        "/1.0/instances/#{instance_slug}/state",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)

          {:ok, %{"action" => action}} = Jason.decode(body)

          assert action in ["stop", "start"]

          assert %{"project" => project} = conn.query_params

          assert project == project_name

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, stop_instance)
        end
      )

      stop_instance_key_params = Jason.decode!(stop_instance)
      stop_instance_operation_id = stop_instance_key_params["metadata"]["id"]

      Bypass.expect_once(
        bypass,
        "GET",
        "/1.0/operations/#{stop_instance_operation_id}/wait",
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

          assert %{"event" => %{"name" => event_name}} = body

          assert event_name in ["restart", "stuck"]

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

      assert perform_job(Restart, %{
               instance: %{
                 slug: instance_slug
               },
               install_id: install.id,
               actor_id: actor.id
             })
    end
  end
end
