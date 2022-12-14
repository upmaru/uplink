defmodule Uplink.Clients.Caddy.Config.BuilderTest do
  use ExUnit.Case

  import Uplink.Scenarios.Deployment

  setup [:setup_endpoints, :setup_base]

  test "generate caddy config" do
    assert %{admin: admin, apps: apps} =
             Uplink.Clients.Caddy.Config.Builder.new()

    assert %{http: %{servers: %{"uplink" => server}}} = apps
    assert %{routes: [route]} = server
    assert %{handle: [handle], match: [match]} = route
    assert %{handler: "reverse_proxy"} = handle
    assert %{host: _hosts} = match

    assert %{identity: identity} = admin
    assert %{issuers: [zerossl]} = identity
    assert %{module: "zerossl"} = zerossl
  end
end
