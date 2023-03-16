defmodule Uplink.Packages.Install.ExecuteTest do
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

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

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

    Application.put_env(:uplink, Uplink.Clients.Instellar,
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

    [instance] = metadata.instances

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

    Cache.delete(:instances)

    {:ok, %{resource: validating_install}} =
      Packages.transition_install_with(install, actor, "validate")

    {:ok, %{resource: executing_install}} =
      Packages.transition_install_with(validating_install, actor, "execute")

    empty_instances = File.read!("test/fixtures/lxd/instances/list/empty.json")

    {:ok,
     install: executing_install,
     actor: actor,
     bypass: bypass,
     instance: instance,
     empty_instances: empty_instances}
  end

  describe "boostrap instance" do
    alias Uplink.Packages.Install.Execute

    test "choose execution path", %{
      bypass: bypass,
      install: install,
      actor: actor,
      instance: instance,
      empty_instances: empty_instances
    } do
      Bypass.expect_once(bypass, "GET", "/1.0/instances", fn conn ->
        %{"recursion" => "1"} = conn.query_params

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, empty_instances)
      end)

      Bypass.expect_once(
        bypass,
        "POST",
        "/uplink/installations/#{install.instellar_installation_id}/instances/#{instance.slug}/events",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)

          assert %{"event" => %{"name" => "boot"}} = Jason.decode!(body)

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{data: %{id: 1}}))
        end
      )

      assert {:ok, jobs} =
               perform_job(Execute, %{
                 install_id: install.id,
                 actor_id: actor.id
               })

      assert Enum.count(jobs) == 1
    end
  end

  describe "upgrade instance" do
    alias Uplink.Packages.Install.Execute

    setup do
      existing_instances =
        File.read!("test/fixtures/lxd/instances/list/existing.json")

      {:ok, existing_instances: existing_instances}
    end

    test "choose upgrade", %{
      bypass: bypass,
      install: install,
      actor: actor,
      instance: instance,
      existing_instances: existing_instances
    } do
      Bypass.expect_once(bypass, "GET", "/1.0/instances", fn conn ->
        %{"recursion" => "1"} = conn.query_params

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, existing_instances)
      end)

      Bypass.expect_once(
        bypass,
        "POST",
        "/uplink/installations/#{install.instellar_installation_id}/instances/#{instance.slug}/events",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)

          assert %{"event" => %{"name" => "upgrade"}} = Jason.decode!(body)

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{data: %{id: 1}}))
        end
      )

      assert {:ok, jobs} =
               perform_job(Execute, %{
                 install_id: install.id,
                 actor_id: actor.id
               })

      assert Enum.count(jobs) == 1
    end
  end
end
