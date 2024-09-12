defmodule Uplink.Packages.Instance.PlacementTest do
  use ExUnit.Case

  import Uplink.Scenarios.Deployment

  alias Uplink.Packages.Instance.Placement

  setup [:setup_endpoints, :setup_base]

  test "name" do
    assert Placement.name("instellar-0e43123-01") == "instellar-0e43123"
  end

  describe "spread placement" do
    setup do
      node_name = "instellar-0e43123-01"

      existing_instances =
        File.read!("test/fixtures/lxd/instances/list/existing.json")

      cluster_members =
        File.read!("test/fixtures/lxd/cluster/members/list.json")

      {:ok,
       existing_instances: existing_instances,
       cluster_members: cluster_members,
       node_name: node_name}
    end

    test "calls lxd api when availability is nil", %{
      bypass: bypass,
      existing_instances: existing_instances,
      node_name: node_name
    } do
      Bypass.expect_once(bypass, "GET", "/1.0/instances", fn conn ->
        assert %{"recursion" => "1", "all-projects" => _} = conn.query_params

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, existing_instances)
      end)

      assert {:ok, %Placement{}} = Placement.find(node_name, "spread")
    end

    test "fallback to auto when no availability", %{
      bypass: bypass,
      existing_instances: existing_instances,
      cluster_members: cluster_members
    } do
      placement_name = Placement.name("instellar-0e89ea876-02")

      Bypass.expect_once(bypass, "GET", "/1.0/instances", fn conn ->
        assert %{"recursion" => "1", "all-projects" => _} = conn.query_params

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, existing_instances)
      end)

      Bypass.expect_once(bypass, "GET", "/1.0/cluster/members", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, cluster_members)
      end)

      Uplink.Cache.put({:available_nodes, placement_name}, [])

      assert {:ok, %Placement{}} = Placement.find(node_name, "spread")
    end
  end
end
