defmodule Uplink.Clustering.LxdTest do
  use ExUnit.Case

  alias Cluster.Strategy.State
  alias Uplink.Cache

  defmodule Nodes do
    def connect(caller, result \\ true, node) do
      send(caller, {:connect, node})
      result
    end

    def disconnect(caller, result \\ true, node) do
      send(caller, {:disconnect, node})
      result
    end

    def list_nodes(nodes) do
      nodes
    end
  end

  setup do
    bypass = Bypass.open()

    Cache.put(:self, %{
      "credential" => %{
        "endpoint" => "http://localhost:#{bypass.port}"
      }
    })

    {:ok, bypass: bypass}
  end

  describe "connect" do
    setup do
      options = [
        %State{
          topology: :uplink,
          connect: {Nodes, :connect, [self()]},
          disconnect: {Nodes, :disconnect, [self()]},
          list_nodes: {Nodes, :list_nodes, [[]]},
          config: [
            app_name: "uplink",
            lxd_profile_name: "uplink-1"
          ]
        }
      ]

      response_with_node = File.read!("test/fixtures/lxd/profiles/show.json")

      {:ok, response: response_with_node, options: options}
    end

    test "it should connect", %{
      bypass: bypass,
      response: response,
      options: options
    } do
      Bypass.expect(bypass, "GET", "/1.0/profiles/uplink-1", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, response)
      end)

      {:ok, _pid} = Uplink.Clustering.LXD.start_link(options)

      assert_receive {:connect, :"uplink@instellar-web2-01"}
    end
  end

  describe "disconnect" do
    setup do
      options = [
        %State{
          topology: :uplink,
          connect: {Nodes, :connect, [self()]},
          disconnect: {Nodes, :disconnect, [self()]},
          list_nodes: {Nodes, :list_nodes, [[:"uplink@instellar-web2-01"]]},
          meta: MapSet.new([:"uplink@instellar-web2-01"]),
          config: [
            app_name: "uplink",
            lxd_profile_name: "uplink-1"
          ]
        }
      ]

      response_with_no_node =
        File.read!("test/fixtures/lxd/profiles/show_no_nodes.json")

      {:ok, response: response_with_no_node, options: options}
    end

    test "it should disconnect", %{
      response: response,
      bypass: bypass,
      options: options
    } do
      Bypass.expect(bypass, "GET", "/1.0/profiles/uplink-1", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, response)
      end)

      {:ok, _pid} = Uplink.Clustering.LXD.start_link(options)

      assert_receive {:disconnect, :"uplink@instellar-web2-01"}
    end
  end
end
