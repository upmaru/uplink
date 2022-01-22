defmodule Uplink.Packages.DistributionTest do
  use ExUnit.Case
  use Plug.Test

  alias Uplink.{
    Clients,
    Members,
    Packages,
    Cache
  }

  alias Clients.LXD

  @app_slug "upmaru/something-1640927800"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)

    bypass = Bypass.open()

    Cache.put(:self, %{
      "credential" => %{
        "endpoint" => "http://localhost:#{bypass.port}"
      }
    })

    Cache.put({:networks, "managed"}, %LXD.Network{
      managed: true,
      name: "lxdfan0"
    })

    deployment_payload = %{
      "actor" => %{
        "identifier" => "zacksiri"
      },
      "installation_id" => 1,
      "deployment" => %{
        "hash" => "some-hash",
        "archive_url" =>
          "archives/7a363fba-8ca7-4ea4-8e84-f3785ac97102/packages.zip",
        "metadata" => %{
          "cluster" => %{
            "credential" => %{
              "certificate" => "cert",
              "endpoint" => "http://localhost:#{bypass.port}",
              "password" => "somepassword",
              "password_confirmation" => "somepassword",
              "private_key" => "key"
            },
            "organization" => %{
              "slug" => "upmaru"
            }
          },
          "id" => 8000,
          "package" => %{
            "slug" => "something-1640927800",
            "organization" => %{
              "slug" => "upmaru"
            }
          }
        }
      }
    }

    {:ok, actor} =
      Members.create_actor(%{
        identifier: "zacksiri"
      })

    app = Packages.get_or_create_app(@app_slug)

    deployment_params = Map.get(deployment_payload, "deployment")

    {:ok, deployment} =
      Packages.get_or_create_deployment(app, deployment_params)

    {:ok, _installation} = Packages.create_install(deployment, 1)

    {:ok, %{resource: preparing_deployment}} =
      Packages.transition_deployment_with(deployment, actor, "prepare")

    leases_list = File.read!("test/fixtures/lxd/networks/leases.json")

    allowed_ips =
      leases_list
      |> Jason.decode!()
      |> Map.get("metadata")
      |> Enum.map(fn data ->
        data["address"]
      end)

    %LXD.Network{} = network = LXD.managed_network()

    Bypass.expect(
      bypass,
      "GET",
      "/1.0/networks/#{network.name}/leases",
      fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, leases_list)
      end
    )

    [first, second, third, fourth] =
      List.first(allowed_ips)
      |> String.split(".")
      |> Enum.map(&String.to_integer/1)

    address = {first, second, third, fourth}

    {:ok,
     actor: actor,
     deployment: preparing_deployment,
     bypass: bypass,
     allowed_ips: allowed_ips,
     address: address}
  end

  describe "matching archive node" do
    setup %{deployment: deployment, actor: actor} do
      {:ok, archive} =
        Packages.create_archive(deployment, %{
          node: "nonode@nohost",
          locations: ["#{@app_slug}/x86_64/APKINDEX.tar.gz"]
        })

      {:ok, %{resource: completed_deployment}} =
        Packages.transition_deployment_with(deployment, actor, "complete")

      {:ok, archive: archive, deployment: completed_deployment}
    end

    test "successfully fetch file", %{address: address} do
      conn =
        conn(:get, "/distribution/#{@app_slug}/x86_64/APKINDEX.tar.gz")
        |> Map.put(:remote_ip, address)
        |> Uplink.Router.call([])

      assert conn.status == 200
    end
  end
end
