defmodule Uplink.Clients.Caddy.Config.BuilderTest do
  use ExUnit.Case

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

  test "generate caddy config" do
    assert %{admin: admin, apps: apps, storage: storage} =
             Uplink.Clients.Caddy.build_new_config()

    assert %{http: %{servers: %{"uplink" => server}}} = apps
    assert %{routes: [first_route, second_route]} = server

    assert %{handle: [handle], match: [match]} = first_route
    assert %{handle: [second_handle], match: [second_match]} = second_route

    assert "grpc.something.com" in second_match.host

    [second_upstream] = second_handle.upstreams

    assert second_upstream.dial =~ "6000"

    assert %{handler: "reverse_proxy"} = handle
    assert %{host: _hosts} = match

    assert %{identity: identity} = admin
    assert %{issuers: [zerossl]} = identity
    assert %{module: "zerossl"} = zerossl

    assert %{module: "s3"} = storage
  end
end
