defmodule Uplink.InternalTest do
  use ExUnit.Case
  use Plug.Test

  alias Uplink.Internal

  @opts Internal.init([])

  import Uplink.Scenarios.Deployment

  setup [:setup_endpoints, :setup_base]

  setup do
    Application.put_env(:uplink, Uplink.Clients.Caddy,
      storage: %{
        prefix: "uplink"
      }
    )

    :ok
  end

  describe "caddy" do
    test "get caddy config", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/uplink/self/routers/1/proxies",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(%{
              "data" => [
                %{
                  "attributes" => %{
                    "id" => 1,
                    "router_id" => 1,
                    "hosts" => ["opsmaru.com", "www.opsmaru.com"],
                    "paths" => ["/how-to*"],
                    "tls" => false,
                    "target" => "proxy.webflow.com",
                    "port" => 80
                  }
                }
              ]
            })
          )
        end
      )

      conn =
        conn(:get, "/caddy")
        |> put_req_header("content-type", "applcation/json")
        |> Internal.call(@opts)

      assert conn.status == 200

      assert %{"admin" => _admin, "apps" => _apps, "storage" => _storage} =
               Jason.decode!(conn.resp_body)
    end
  end
end
