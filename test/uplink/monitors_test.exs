defmodule Uplink.MonitorsTest do
  use ExUnit.Case

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

  setup do
    bypass = Bypass.open()

    Application.put_env(
      :uplink,
      Uplink.Clients.Instellar,
      endpoint: "http://localhost:#{bypass.port}/uplink"
    )

    {:ok, bypass: bypass}
  end

  test "run", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/uplink/self/monitors", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(@monitors_response))
    end)

    assert :ok == Uplink.Monitors.run()
  end
end
