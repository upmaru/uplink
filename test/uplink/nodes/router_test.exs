defmodule Uplink.Nodes.RouterTest do
  use ExUnit.Case
  use Plug.Test

  alias Uplink.Cache
  alias Uplink.Nodes.Router

  @opts Router.init([])

  @valid_body Jason.encode!(%{
                "actor" => %{
                  "provider" => "instellar",
                  "identifier" => "zacksiri",
                  "id" => "1"
                }
              })

  setup do
    bypass = Bypass.open()

    Cache.put(:self, %{
      "credential" => %{
        "endpoint" => "http://localhost:#{bypass.port}"
      }
    })

    members_response = File.read!("test/fixtures/lxd/cluster/members/list.json")

    resource_response = File.read!("test/fixtures/lxd/resources/show.json")

    Cache.delete(:cluster_members)

    {:ok,
     bypass: bypass,
     members_response: members_response,
     resource_response: resource_response}
  end

  describe "list nodes" do
    setup do
      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), @valid_body)
        |> Base.encode16()
        |> String.downcase()

      {:ok, signature: signature}
    end

    test "can successfully fetch list of nodes", %{
      bypass: bypass,
      signature: signature,
      members_response: members_response,
      resource_response: resource_response
    } do
      Bypass.expect_once(bypass, "GET", "/1.0/cluster/members", fn conn ->
        assert %{"recursion" => "1"} = conn.query_params

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, members_response)
      end)

      Bypass.expect_once(bypass, "GET", "/1.0/resources", fn conn ->
        assert %{"target" => "ubuntu-s-1vcpu-1gb-sgp1-01"} = conn.params

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, resource_response)
      end)

      conn =
        conn(:post, "/", @valid_body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert %{"data" => nodes} = Jason.decode!(conn.resp_body)

      [node] = nodes

      assert %{
               "cpu_cores_count" => _,
               "name" => _,
               "total_memory" => _,
               "total_storage" => _
             } = node

      assert conn.status == 200
    end
  end
end
