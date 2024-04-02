defmodule Uplink.Clients.LXDTest do
  use ExUnit.Case

  alias Uplink.Clients
  alias Uplink.Cache

  alias Uplink.Clients.LXD

  setup do
    Cache.put(:self, %{
      "balancer" => %{
        "address" => "some.address.com",
        "current_state" => "active"
      },
      "credential" => %{
        "endpoint" => "http://localhost:8443"
      }
    })
  end

  describe "client" do
    test "use balancer address" do
      assert %Tesla.Client{pre: pre} = LXD.client()

      {_, _, [base_url]} =
        Enum.find(pre, fn {middleware, _, _} ->
          middleware == Tesla.Middleware.BaseUrl
        end)

      assert base_url == "https://some.address.com:8443"
    end
  end
end
