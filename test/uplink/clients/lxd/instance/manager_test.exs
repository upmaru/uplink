defmodule Uplink.Clients.LXD.Instance.ManagerTest do
  use ExUnit.Case
  
  alias Uplink.{
    Cache,
    Clients
  }
  
  alias Clients.LXD
  alias LXD.Instance
  
  setup do
    bypass = Bypass.open()
    
    Cache.put(:self, %{
      "credential" => %{
        "endpoint" => "http://localhost:#{bypass.port}"
      }
    })
    
    response = File.read!("test/fixtures/lxd/instances/list.json")
    
    {:ok, bypass: bypass, response: response}
  end
  
  describe "list leases" do
    alias Instance.Manager
    
    test "return instances", %{bypass: bypass, response: response} do
      Bypass.expect_once(bypass, "GET", "/1.0/instances", fn conn -> 
        assert %{"recursive" => "1"} = conn.query_params
        
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, response)
      end)
      
      assert [_instance1, _instance2] = Manager.list()
    end
  end
end