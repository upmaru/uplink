defmodule Uplink.Cache.RouterTest do
  use ExUnit.Case
  use Plug.Test

  alias Uplink.Cache.Router

  @opts Router.init([])

  @valid_delete_body Jason.encode!(%{
                       "actor" => %{
                         "provider" => "instellar",
                         "identifier" => "zacksiri",
                         "id" => "1"
                       }
                     })

  describe "delete self" do
    setup do
      bypass = Bypass.open()

      Application.put_env(
        :uplink,
        Uplink.Clients.Instellar,
        endpoint: "http://localhost:#{bypass.port}/uplink"
      )

      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), @valid_delete_body)
        |> Base.encode16()
        |> String.downcase()

      {:ok, signature: signature, bypass: bypass}
    end

    test "can successfully delete :self", %{signature: signature} do
      conn =
        conn(:delete, "/self", @valid_delete_body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 200
    end

    test "can successfully delete {:proxies, router_id}", %{
      signature: signature,
      bypass: bypass
    } do
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

      conn =
        conn(:delete, "/routers/1/proxies", @valid_delete_body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 200
    end
  end
end
