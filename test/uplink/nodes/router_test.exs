defmodule Uplink.Nodes.RouterTest do
  use ExUnit.Case
  use Plug.Test

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
end
