defmodule Uplink.AvailabilityTest do
  use ExUnit.Case

  alias Uplink.Cache
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
      },
      "uplink" => %{"id" => 1}
    })

    cluster_members_response =
      File.read!("test/fixtures/lxd/cluster/members/list.json")

    monitors_list_response =
      File.read!("test/fixtures/instellar/monitors/list.json")

    %{"data" => [monitor]} = Jason.decode!(monitors_list_response)

    %{"attributes" => attributes} = monitor

    attributes =
      Map.put(attributes, "endpoint", "http://localhost:#{bypass.port}")

    monitors_list_response =
      Jason.encode_to_iodata!(%{
        "data" => [
          %{"attributes" => attributes}
        ]
      })

    resources_response = File.read!("test/fixtures/lxd/resources/show.json")

    availability_query_response =
      File.read!("test/fixtures/elastic/availability.json")

    Cache.delete(:cluster_members)

    {:ok,
     bypass: bypass,
     resources_response: resources_response,
     cluster_members_response: cluster_members_response,
     availability_query_response: availability_query_response,
     monitors_list_response: monitors_list_response}
  end

  describe "check availability of the nodes in the cluster" do
    test "return availability check result", %{
      bypass: bypass,
      resources_response: resource_response,
      availability_query_response: availability_query_response,
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

      Bypass.expect_once(bypass, "GET", "/1.0/resources", fn conn ->
        assert %{"target" => _target} = conn.query_params

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, resource_response)
      end)

      Bypass.expect_once(bypass, "POST", "/_msearch", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, availability_query_response)
      end)

      assert {:ok, resources} = Availability.check!()

      assert [%Availability.Resource{} = resource] = resources
    end
  end
end
