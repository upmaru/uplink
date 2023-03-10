defmodule Uplink.Packages.Instance.CleanupTest do
  use ExUnit.Case
  use Oban.Testing, repo: Uplink.Repo

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

    stop_instance = File.read!("test/fixtures/lxd/instances/stop.json")
    delete_instance = File.read!("test/fixtures/lxd/instances/delete.json")
    wait_for_operation = File.read!("test/fixtures/lxd/operations/wait.json")

    show_instance = File.read!("test/fixtures/lxd/instances/show.json")

    instance_not_found =
      File.read!("test/fixtures/lxd/instances/not_found.json")

    metadata = Map.get(@deployment_params, "metadata")

    {:ok, metadata} = Packages.parse_metadata(metadata)

    app =
      metadata
      |> Metadata.app_slug()
      |> Packages.get_or_create_app()

    {:ok, deployment} =
      Packages.get_or_create_deployment(app, @deployment_params)

    {:ok, install} = Packages.create_install(deployment, 1)

    {:ok,
     bypass: bypass,
     actor: actor,
     install: install,
     stop_instance: stop_instance,
     wait_for_operation: wait_for_operation,
     show_instance: show_instance,
     instance_not_found: instance_not_found,
     delete_instance: delete_instance}
  end

  describe "clean up instance" do
    alias Uplink.Packages.Instance.Cleanup

    test "clean up", %{
      bypass: bypass,
      install: install,
      actor: actor,
      stop_instance: stop_instance,
      delete_instance: delete_instance,
      show_instance: show_instance,
      wait_for_operation: wait_for_operation
    } do
      instance_slug = "test-02"

      Bypass.expect_once(
        bypass,
        "GET",
        "/1.0/instances/#{instance_slug}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, show_instance)
        end
      )

      Bypass.expect_once(
        bypass,
        "PUT",
        "/1.0/instances/#{instance_slug}/state",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, stop_instance)
        end
      )

      stop_instance_key_params = Jason.decode!(stop_instance)
      stop_instance_operation_id = stop_instance_key_params["metadata"]["id"]

      Bypass.expect(
        bypass,
        "GET",
        "/1.0/operations/#{stop_instance_operation_id}/wait",
        fn conn ->
          assert %{"timeout" => "120"} = conn.query_params

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, wait_for_operation)
        end
      )

      Bypass.expect_once(
        bypass,
        "DELETE",
        "/1.0/instances/#{instance_slug}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, delete_instance)
        end
      )

      delete_instance_key_params = Jason.decode!(delete_instance)

      delete_instance_operation_id =
        delete_instance_key_params["metadata"]["id"]

      Bypass.expect(
        bypass,
        "GET",
        "/1.0/operations/#{delete_instance_operation_id}/wait",
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

          assert event_name == "off"

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

      assert perform_job(Cleanup, %{
               instance: %{
                 slug: instance_slug,
                 current_state: "deactivating",
                 node: %{slug: "ubuntu-s-1vcpu-1gb-sgp1-01"}
               },
               install_id: install.id,
               actor_id: actor.id
             })

      assert_enqueued(
        worker: Uplink.Clients.Caddy.Config.Reload,
        args: %{install_id: install.id}
      )
    end

    test "clean up when instances does not exist", %{
      bypass: bypass,
      install: install,
      actor: actor,
      instance_not_found: instance_not_found
    } do
      instance_slug = "test-02"

      Bypass.expect_once(
        bypass,
        "GET",
        "/1.0/instances/#{instance_slug}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(404, instance_not_found)
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

          assert event_name == "off"

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

      assert perform_job(Cleanup, %{
               instance: %{
                 slug: instance_slug,
                 current_state: "deactivating",
                 node: %{slug: "ubuntu-s-1vcpu-1gb-sgp1-01"}
               },
               install_id: install.id,
               actor_id: actor.id
             })
    end
  end
end
