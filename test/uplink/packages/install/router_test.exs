defmodule Uplink.Packages.Install.RouterTest do
  use ExUnit.Case
  use Plug.Test

  import Uplink.Scenarios.Deployment

  alias Uplink.{
    Packages,
    Clients,
    Cache
  }

  alias Clients.LXD

  alias Packages.Install.Router

  @opts Router.init([])

  setup [:setup_endpoints, :setup_base]

  setup %{bypass: bypass} do
    Cache.put({:networks, "managed"}, %LXD.Network{
      managed: true,
      name: "lxdfan0"
    })

    leases_list = File.read!("test/fixtures/lxd/networks/leases.json")

    allowed_ips =
      leases_list
      |> Jason.decode!()
      |> Map.get("metadata")
      |> Enum.map(fn data ->
        data["address"]
      end)

    %LXD.Network{} = network = LXD.managed_network()

    Uplink.Cache.delete({:leases, "uplink"})

    project_found = File.read!("test/fixtures/lxd/projects/show.json")

    Bypass.expect(
      bypass,
      "GET",
      "/1.0/projects/default",
      fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, project_found)
      end
    )

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

    {:ok, address: address}
  end

  describe "renders variables" do
    test "successfully returns variables", %{install: install, address: address} do
      conn =
        conn(:get, "/#{install.instellar_installation_id}/variables")
        |> Map.put(:remote_ip, address)
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 200

      assert %{"data" => %{"attributes" => %{"variables" => variables}}} =
               Jason.decode!(conn.resp_body)

      assert %{"SOMETHING" => "blah"} = variables
    end
  end
end
