defmodule Uplink.Clients.LXDTest do
  use ExUnit.Case

  alias Uplink.Cache

  alias Uplink.Clients.LXD

  describe "balancer is nil" do
    setup do
      Cache.put(:self, %{
        "balancer" => nil,
        "credential" => %{
          "endpoint" => "http://localhost:8443"
        }
      })
    end

    test "use credential endpoint" do
      assert %Tesla.Client{pre: pre} = LXD.client()

      {_, _, [base_url]} =
        Enum.find(pre, fn {middleware, _, _} ->
          middleware == Tesla.Middleware.BaseUrl
        end)

      assert base_url == "http://localhost:8443"
    end
  end

  describe "client without balancer" do
    setup do
      Cache.put(:self, %{
        "credential" => %{
          "endpoint" => "http://localhost:8443"
        }
      })
    end

    test "use credential endpoint" do
      assert %Tesla.Client{pre: pre} = LXD.client()

      {_, _, [base_url]} =
        Enum.find(pre, fn {middleware, _, _} ->
          middleware == Tesla.Middleware.BaseUrl
        end)

      assert base_url == "http://localhost:8443"
    end
  end

  describe "client with blaancer" do
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

    test "use balancer address" do
      assert %Tesla.Client{pre: pre} = LXD.client()

      {_, _, [base_url]} =
        Enum.find(pre, fn {middleware, _, _} ->
          middleware == Tesla.Middleware.BaseUrl
        end)

      assert base_url == "http://some.address.com:8443"
    end
  end
end
