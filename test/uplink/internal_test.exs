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
    test "get caddy config" do
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
