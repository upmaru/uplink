defmodule Uplink.Clients.LXD.Cluster.ManagerTest do
  use ExUnit.Case

  alias Uplink.{
    Cache,
    Clients
  }

  alias Clients.LXD
  alias LXD.Cluster

  setup do
    bypass = Bypass.open()

    Cache.put(:self, %{
      "credential" => %{
        "endpoint" => "http://localhost:#{bypass.port}"
      }
    })

    response = File.read!("test/fixtures/lxd/cluster/members/list.json")

    Cache.delete(:cluster_members)

    {:ok, bypass: bypass, response: response}
  end

  describe "list cluster members" do
    alias Cluster.Manager

    test "return cluster members", %{bypass: bypass, response: response} do
      Bypass.expect_once(bypass, "GET", "/1.0/cluster/members", fn conn ->
        assert %{"recursive" => "1"} = conn.query_params

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, response)
      end)

      assert [member1] = Manager.list_members()
      assert %Cluster.Member{} = member1
    end
  end
end
