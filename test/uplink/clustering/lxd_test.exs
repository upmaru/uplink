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

    response = File.read!("test/fixtures/lxd/profiles/show.json")

    {:ok, bypass: bypass, options: options, response: response}
  end

  test "info call :load", %{
    bypass: bypass,
    options: options,
    response: response
  } do
    Bypass.expect(bypass, "GET", "/1.0/profiles/uplink-1", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, response)
    end)

    {:ok, pid} = Uplink.Clustering.LXD.start_link(options)

    assert :load == send(pid, :load)

    assert_receive {:connect, :"uplink@instellar-web2-01"}
  end
end
