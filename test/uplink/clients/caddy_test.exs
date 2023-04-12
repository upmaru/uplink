defmodule Uplink.Clients.CaddyTest do
  use ExUnit.Case

  alias Uplink.Clients.Caddy
  alias Caddy.Apps

  setup do
    bypass = Bypass.open()

    Application.put_env(
      :uplink,
      Uplink.Clients.Caddy,
      endpoint: "http://localhost:#{bypass.port}"
    )

    response = File.read!("test/fixtures/caddy/config/get.json")

    {:ok, bypass: bypass, response: response}
  end

  describe "get config" do
    test "get and parse config", %{bypass: bypass, response: response} do
      Bypass.expect(bypass, "GET", "/config/", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, response)
      end)

      assert {:ok, config} = Caddy.get_config()

      assert %{apps: %Caddy.Apps{}} = config
    end
  end

  describe "load config" do
    test "successfully load config into caddy", %{
      bypass: bypass,
      response: response
    } do
      response = Jason.decode!(response)

      params = %{apps: Apps.parse(response["apps"])}

      Bypass.expect(bypass, "POST", "/load", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, "")
      end)

      assert {:ok, ""} = Caddy.load_config(params)
    end
  end
end
