defmodule Uplink.Routings.Proxy.ManagerTest do
  use ExUnit.Case

  alias Uplink.Cache
  alias Uplink.Routings

  setup do
    bypass = Bypass.open()

    Application.put_env(
      :uplink,
      Uplink.Clients.Instellar,
      endpoint: "http://localhost:#{bypass.port}/uplink"
    )

    {:ok, bypass: bypass}
  end

  describe "list proxies" do
    test "fetch and parse proxies", %{bypass: bypass} do
      Cache.delete({:proxies, 1})

      Bypass.expect_once(
        bypass,
        "GET",
        "/uplink/self/routers/1/proxies",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode_to_iodata!(%{
              "data" => [
                %{
                  "attributes" => %{
                    "id" => 1,
                    "router_id" => 1,
                    "hosts" => ["opsmaru.com", "www.opsmaru.com"],
                    "paths" => ["/how-to*"],
                    "tls" => true,
                    "target" => "proxy.webflow.com",
                    "port" => 80
                  }
                }
              ]
            })
          )
        end
      )

      assert [%Routings.Proxy{} = _proxy] = Routings.list_proxies(1)
    end
  end
end
