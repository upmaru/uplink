defmodule Uplink.Clients.LXD.Network.ManagerTest do
  use ExUnit.Case

  alias Uplink.{
    Cache,
    Clients
  }

  alias Clients.LXD
  alias LXD.Network
  alias Network.Lease

  setup do
    bypass = Bypass.open()

    Cache.put(:self, %{
      "credential" => %{
        "endpoint" => "http://localhost:#{bypass.port}"
      }
    })

    response = File.read!("test/fixtures/lxd/networks/list.json")
    
    Cache.delete({:networks, "managed"})

    {:ok, bypass: bypass, response: response}
  end

  describe "managed" do
    alias Network.Manager

    test "return managed network", %{bypass: bypass, response: response} do
      Bypass.expect_once(bypass, "GET", "/1.0/networks", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, response)
      end)

      assert %Network{managed: true, name: name} = Manager.managed()
      refute is_nil(name)
    end
  end
  
  describe "leases" do
    alias Network.Manager
    
    setup %{bypass: bypass, response: response} do
      Bypass.expect_once(bypass, "GET", "/1.0/networks", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, response)
      end)
      
      response = File.read!("test/fixtures/lxd/networks/leases.json")
      
      
      %Network{} = network = Manager.managed()
      
      Cache.put({:networks, "managed"}, network)
      
      {:ok, network: network, response: response}
    end
    
    test "return leases", %{bypass: bypass, network: network, response: response} do
      Bypass.expect_once(bypass, "GET", "/1.0/networks/#{network.name}/leases", fn conn -> 
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, response)
      end)
      
      assert [lease, _] = Manager.leases()
      
      assert %Lease{} = lease  
    end
  end
end
