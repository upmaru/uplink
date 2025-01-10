defmodule Uplink.Availability.RouterTest do
  use ExUnit.Case
  use Plug.Test

  alias Uplink.Cache
  alias Uplink.Availability.Router

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

    Application.put_env(
      :uplink,
      Uplink.Clients.Instellar,
      endpoint: "http://localhost:#{bypass.port}/uplink"
    )

    Cache.put(:self, %{
      "credential" => %{
        "endpoint" => "http://localhost:#{bypass.port}"
      },
      "uplink" => %{"id" => 1}
    })

    cluster_members_response =
      File.read!("test/fixtures/lxd/cluster/members/list.json")

    monitors_list_response =
      File.read!("test/fixtures/instellar/monitors/list.json")

    %{"data" => [monitor]} = Jason.decode!(monitors_list_response)

    %{"attributes" => attributes} = monitor

    attributes =
      Map.put(attributes, "endpoint", "http://localhost:#{bypass.port}")

    monitors_list_response =
      Jason.encode_to_iodata!(%{
        "data" => [
          %{"attributes" => attributes}
        ]
      })

    resources_response = File.read!("test/fixtures/lxd/resources/show.json")

    availability_query_response =
      File.read!("test/fixtures/elastic/availability.json")

    Cache.delete(:cluster_members)

    {:ok,
     bypass: bypass,
     resources_response: resources_response,
     cluster_members_response: cluster_members_response,
     availability_query_response: availability_query_response,
     monitors_list_response: monitors_list_response}
  end

  describe "POST /resources" do
    setup do
      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), @valid_body)
        |> Base.encode16()
        |> String.downcase()

      {:ok, signature: signature}
    end

    test "can successfully fetch resources with availability", %{
      bypass: bypass,
      signature: signature,
      resources_response: resource_response,
      availability_query_response: availability_query_response,
      cluster_members_response: cluster_members_response,
      monitors_list_response: monitors_list_response
    } do
      Bypass.expect_once(bypass, "GET", "/uplink/self/monitors", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, monitors_list_response)
      end)

      Bypass.expect_once(bypass, "GET", "/1.0/cluster/members", fn conn ->
        assert %{"recursion" => "1"} = conn.query_params

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, cluster_members_response)
      end)

      Bypass.expect_once(bypass, "GET", "/1.0/resources", fn conn ->
        assert %{"target" => _target} = conn.query_params

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, resource_response)
      end)

      Bypass.expect_once(bypass, "POST", "/_msearch", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, availability_query_response)
      end)

      conn =
        conn(:post, "/resources", @valid_body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert %{"data" => resources} = Jason.decode!(conn.resp_body)

      [resource] = resources

      assert %{
               "node" => _node,
               "total" => _total,
               "used" => _used,
               "available" => _available
             } = resource
    end
  end
end
