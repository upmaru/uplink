defmodule Uplink.Packages.Instance.UpgradeTest do
  use ExUnit.Case
  use Oban.Testing, repo: Uplink.Repo

  import Uplink.Scenarios.Deployment

  setup [:setup_endpoints, :setup_base]

  describe "upgrade instance" do
    alias Uplink.Packages.Instance.Upgrade

    setup do
      exec_instance = File.read!("test/fixtures/lxd/instances/exec.json")

      wait_with_log =
        File.read!("test/fixtures/lxd/operations/wait_with_log.json")

      {:ok, exec_instance: exec_instance, wait_with_log: wait_with_log}
    end

    test "perform", %{
      bypass: bypass,
      actor: actor,
      install: install,
      exec_instance: exec_instance,
      wait_with_log: wait_with_log,
      metadata: metadata
    } do
      instance_slug = "some-instance-01"

      Bypass.expect_once(
        bypass,
        "POST",
        "/1.0/instances/#{instance_slug}/exec",
        fn conn ->
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

      assert {:ok, _transition} =
               perform_job(Upgrade, %{
                 instance: %{
                   slug: instance_slug,
                   node: %{slug: "some-node-01"}
                 },
                 install_id: install.id,
                 actor_id: actor.id
               })
    end

    test "on error it enqueue deactivate and bootstrap", %{
      bypass: bypass,
      actor: actor,
      install: install,
      exec_instance: exec_instance,
      wait_with_log: wait_with_log,
      metadata: metadata
    } do
      instance_slug = "some-instance-01"

      Bypass.expect_once(
        bypass,
        "POST",
        "/1.0/instances/#{instance_slug}/exec",
        fn conn ->
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
  end
end
