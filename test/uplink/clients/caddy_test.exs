defmodule Uplink.Clients.CaddyTest do
  use ExUnit.Case

  alias Uplink.Clients.Caddy

  setup do
    bypass = Bypass.open()

    Application.put_env(
      :uplink,
      Uplink.Clients.Caddy,
      endpoint: "http://localhost:#{bypass.port}"
    )

    config_params = File.read!("test/fixtures/caddy/config/get.json")

    {:ok, bypass: bypass, config_params: config_params}
  end

  describe "get config" do
    test "get and parse config", %{bypass: bypass, config_params: config_params} do
      Bypass.expect(bypass, "GET", "/config/", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, config_params)
      end)

      assert {:ok, config} = Caddy.get_config()

      assert %{apps: %Caddy.Apps{}} = config
    end
  end

  describe "load config" do
    test "successfully load config into caddy", %{
      bypass: bypass,
      config_params: config_params
    } do
      Bypass.expect(bypass, "POST", "/load", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, "")
      end)

      assert {:ok, ""} = Caddy.load_config(config_params)
    end
  end
end
