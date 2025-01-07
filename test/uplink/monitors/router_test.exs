defmodule Uplink.Monitors.RouterTest do
  use ExUnit.Case
  use Plug.Test

  alias Uplink.Monitors.Router

  @opts Router.init([])

  @monitors_response %{
    "data" => [
      %{
        "attributes" => %{
          "current_state" => "active",
          "endpoint" => "https://elastic:9200",
          "expires_at" => "2024-11-21T03:14:17Z",
          "id" => 1,
          "token" => "some-token",
          "type" => "metrics",
          "uid" => "some-uid"
        },
        "id" => "1",
        "links" => %{"self" => "http://localhost:4000/uplink/self/monitors/1"},
        "relationships" => %{},
        "type" => "monitors"
      }
    ],
    "included" => [],
    "links" => %{"self" => "http://localhost:4000/uplink/self/monitors"}
  }

  @valid_refresh_body Jason.encode!(%{
                        "actor" => %{
                          "provider" => "instellar",
                          "identifier" => "zacksiri",
                          "id" => "1"
                        }
                      })

  setup do
    bypass = Bypass.open()

    Application.put_env(
      :uplink,
      Uplink.Clients.Instellar,
      endpoint: "http://localhost:#{bypass.port}/uplink"
    )

    Uplink.Cache.put({:monitors, :metrics}, [
      %{
        "attributes" => %{
          "current_state" => "active",
          "endpoint" => "https://elastic:9200",
          "expires_at" => "2024-11-21T03:14:17Z",
          "id" => 1,
          "token" => "some-token",
          "type" => "metrics",
          "uid" => "some-other-uid"
        },
        "id" => "1",
        "links" => %{"self" => "http://localhost:4000/uplink/self/monitors/1"},
        "relationships" => %{},
        "type" => "monitors"
      }
    ])

    {:ok, bypass: bypass}
  end

  describe "refresh monitors" do
    setup do
      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), @valid_refresh_body)
        |> Base.encode16()
        |> String.downcase()

      {:ok, signature: signature}
    end

    test "can refresh monitors list", %{signature: signature, bypass: bypass} do
      [monitor] = Uplink.Pipelines.get_monitors(:metrics)

      assert monitor["attributes"]["uid"] == "some-other-uid"

      Bypass.expect_once(bypass, "GET", "/uplink/self/monitors", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(@monitors_response))
      end)

      conn =
        conn(:post, "/refresh", @valid_refresh_body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      [monitor] = Uplink.Pipelines.get_monitors(:metrics)

      assert monitor["attributes"]["uid"] == "some-uid"

      assert conn.status == 200
    end
  end
end
