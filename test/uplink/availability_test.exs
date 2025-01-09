defmodule Uplink.AvailabilityTest do
  use ExUnit.Case

  alias Uplink.Availability

  setup do
    bypass = Bypass.open()

    Cache.put(:self, %{
      "credential" => %{
        "endpoint" => "http://localhost:#{bypass.port}"
      }
    })

    response = File.read!("test/fixtures/lxd/cluster/members/list.json")

    Cache.delete(:cluster_members)

    {:ok, bypass: bypass}
  end

  describe "check availability of the nodes in the cluster" do
    test "return availability check result", %{
      bypass: bypass,
      response: response
    } do
      Bypass.expect_once(bypass, "GET", "/1.0/cluster/members", fn conn ->
        assert %{"recursion" => "1"} = conn.query_params

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, response)
      end)

      assert {:ok, result} = Availability.check!()
    end
  end
end
