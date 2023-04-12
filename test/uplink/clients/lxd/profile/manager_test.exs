defmodule Uplink.Clients.LXD.Profile.ManagerTest do
  use ExUnit.Case

  alias Uplink.{
    Cache,
    Clients
  }

  alias Clients.LXD
  alias LXD.Profile

  setup do
    bypass = Bypass.open()

    Cache.put(:self, %{
      "credential" => %{
        "endpoint" => "http://localhost:#{bypass.port}"
      }
    })

    response = File.read!("test/fixtures/lxd/profiles/list.json")

    Cache.delete(:profiles)

    {:ok, bypass: bypass, response: response}
  end

  describe "list profiles" do
    alias Profile.Manager

    test "return profiles", %{bypass: bypass, response: response} do
      Bypass.expect_once(bypass, "GET", "/1.0/profiles", fn conn ->
        assert %{"recursion" => "1"} = conn.query_params

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, response)
      end)

      assert [profile1, _profile2, _profile3] = Manager.list()
      assert %Profile{} = profile1
    end
  end
end
