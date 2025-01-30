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
      File.read!("test/fixtures/lxd/cluster/members/arrakis.json")

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

    availability_query_response =
      File.read!("test/fixtures/elastic/availability.json")

    instances_response = File.read!("test/fixtures/lxd/instances/list.json")

    resource_response = File.read!("test/fixtures/lxd/resources/arrakis.json")

    Cache.delete(:cluster_members)
    Cache.delete({:monitors, :metrics})

    {:ok,
     bypass: bypass,
     cluster_members_response: cluster_members_response,
     availability_query_response: availability_query_response,
     monitors_list_response: monitors_list_response,
     instances_response: instances_response,
     resource_response: resource_response}
  end

  describe "check availability of the nodes in the cluster" do
    setup %{
      bypass: bypass,
      availability_query_response: availability_query_response,
      cluster_members_response: cluster_members_response,
      monitors_list_response: monitors_list_response,
      instances_response: instances_response,
      resource_response: resource_response
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

      Bypass.expect(bypass, "GET", "/1.0/resources", fn conn ->
        assert %{"target" => "arrakis"} = conn.query_params

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, resource_response)
      end)

      Bypass.expect_once(bypass, "POST", "/_msearch", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, availability_query_response)
      end)

      Bypass.expect_once(bypass, "GET", "/1.0/instances", fn conn ->
        assert %{"project" => "test"} = conn.query_params

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, instances_response)
      end)

      :ok
    end

    test "return availability check result when all resources are available" do
      {:ok, requirements} =
        Availability.process_requirement(%{
          "project" => "test",
          "cpu" => 1,
          "memory" => 128_000_000,
          "disk" => 300_000_000
        })

      assert {:ok, resources} = Availability.check!(requirements)

      assert [%Availability.Resource{placeability: placeability}] = resources

      assert %Availability.Placeability{
               cpu: Decimal.new("1.0"),
               memory: Decimal.new("0.9999998211860657"),
               disk: Decimal.new("1.0")
             } == placeability
    end

    test "return availability check result when all memory is not available" do
      {:ok, requirements} =
        Availability.process_requirement(%{
          "project" => "test",
          "cpu" => 1,
          "memory" => 64_000_000_000,
          "disk" => 300_000_000
        })

      assert {:ok, resources} = Availability.check!(requirements)

      assert [%Availability.Resource{placeability: placeability}] = resources

      assert %Availability.Placeability{
               cpu: Decimal.new("1.0"),
               memory: Decimal.new("0.0"),
               disk: Decimal.new("1.0")
             } == placeability
    end

    test "return availability check result when cpu and memory is not available" do
      {:ok, requirements} =
        Availability.process_requirement(%{
          "project" => "test",
          "cpu" => 36,
          "memory" => 64_000_000_000,
          "disk" => 300_000_000
        })

      assert {:ok, resources} = Availability.check!(requirements)

      assert [%Availability.Resource{placeability: placeability}] = resources

      assert %Availability.Placeability{
               cpu: Decimal.new("7.951236069532033E-35"),
               memory: Decimal.new("0.0"),
               disk: Decimal.new("1.0")
             } == placeability
    end

    test "return availability check result when cpu, memory and disk is not available" do
      {:ok, requirements} =
        Availability.process_requirement(%{
          "project" => "test",
          "cpu" => 36,
          # 64GB requested
          "memory" => 64_000_000_000,
          # 24TB requested
          "disk" => 24_000_000_000_000
        })

      assert {:ok, resources} = Availability.check!(requirements)

      assert [%Availability.Resource{placeability: placeability}] = resources

      assert %Availability.Placeability{
               cpu: Decimal.new("7.951236069532033E-35"),
               memory: Decimal.new("0.0"),
               disk: Decimal.new("0.0")
             } == placeability
    end
  end
end
