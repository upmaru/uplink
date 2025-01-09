defmodule Uplink.AvailabilityTest do
  use ExUnit.Case

  alias Uplink.Availability

  setup do
    bypass = Bypass.open()

    Application.put_env(
      :uplink,
      Uplink.Clients.Instellar,
      endpoint: "http://localhost:#{bypass.port}/uplink"
    )

    Cache.put(:self, %{
      "credential" => %{
        "endpoint" => "http://localhost:#{bypass.port}"
      }
    })

    cluster_members_response =
      File.read!("test/fixtures/lxd/cluster/members/list.json")

    monitors_list_response =
      File.read!("test/fixtures/instellar/monitors/list.json")

    Cache.delete(:cluster_members)

    {:ok,
     bypass: bypass,
     cluster_members_response: cluster_members_response,
     monitors_list_response: monitors_list_response}
  end

  describe "check availability of the nodes in the cluster" do
    test "return availability check result", %{
      bypass: bypass,
      cluster_members_response: cluster_members_response,
      monitors_list_response: monitors_list_response
    } do
      Bypass.expect_once(bypass, "GET", "/uplink/self/monitors", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, monitors_list_response)
      end)

      Bypass.expect_once(bypass, "GET", "/1.0/cluster/members", fn conn ->
        assert %{"recursion" => "1"} = conn.query_params

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, cluster_members_response)
      end)

      assert {:ok, result} = Availability.check!()
    end
  end
end
