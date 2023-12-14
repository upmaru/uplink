defmodule Uplink.Components.Instance.ModifyTest do
  use ExUnit.Case
  use Oban.Testing, repo: Uplink.Repo

  alias Uplink.Components.Instance

  import Mox

  @cors_config """
  [
    {
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["PUT"],
      "AllowedOrigins": ["*"],
      "ExposeHeaders": []
    }
  ]
  """

  @component_instance_attributes %{
    "id" => 1,
    "current_state" => "active",
    "credential" => %{
      "type" => "instance",
      "username" => "someaccesskey",
      "password" => "somesecretkey",
      "host" => "s3.amazonaws.com",
      "resource" => "us-east-1"
    }
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

  describe "postgresql database" do
    test "return the same credential as retrieved", %{bypass: bypass} do
      component_credential = %{
        "username" => "master",
        "password" => "masterpassword",
        "host" => "some.db.com",
        "resource" => "instellardb"
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/uplink/self/components/1",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "data" => %{
                "attributes" => %{
                  "generator" => %{"module" => "database/postgresql"},
                  "credential" => component_credential
                }
              }
            })
          )
        end
      )

      postgresql_instance_attributes = %{
        "id" => 1,
        "current_state" => "active",
        "credential" => %{
          "username" => "postgresql",
          "password" => "instancepassword",
          "host" => "some.db.com",
          "resource" => "some_db_1234"
        }
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/uplink/self/components/1/instances/1",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "data" => %{
                "attributes" => postgresql_instance_attributes
              }
            })
          )
        end
      )

      Bypass.expect_once(
        bypass,
        "PATCH",
        "/uplink/self/components/1/instances/1",
        fn conn ->
          {:ok, body, _} = Plug.Conn.read_body(conn)

          {:ok, data} = Jason.decode(body)

          assert %{"instance" => %{"credential" => %{"username" => username}}} =
                   data

          assert username ==
                   postgresql_instance_attributes["credential"]["username"]

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "data" => %{
                "attributes" => postgresql_instance_attributes
              }
            })
          )
        end
      )

      assert {:ok, _result} =
               perform_job(Instance.Modify, %{
                 component_id: "1",
                 variable_id: "1",
                 component_instance_id: "1",
                 arguments: %{}
               })
    end
  end

  describe "s3 bucket" do
    test "modify s3 bucket cors config", %{bypass: bypass} do
      Uplink.Drivers.Bucket.AwsMock
      |> expect(:modify, fn _params, options ->
        assert [acl: _, cors: _] = options

        {:ok,
         %Formation.S3.Credential{
           secret_access_key: "somesecret",
           bucket: "some-bucket-name",
           access_key_id: "someaccesskey",
           endpoint: "s3.us-east-1.s3endpoint.com",
           region: "us-east-1",
           cors: Jason.decode!(@cors_config)
         }}
      end)

      Bypass.expect_once(
        bypass,
        "GET",
        "/uplink/self/components/1",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "data" => %{
                "attributes" => %{
                  "generator" => %{"module" => "bucket/aws-s3"},
                  "credential" => %{
                    "type" => "component",
                    "username" => "someaccesskey",
                    "password" => "somesecretkey",
                    "host" => "s3.amazonaws.com",
                    "resource" => "us-east-1"
                  }
                }
              }
            })
          )
        end
      )

      Bypass.expect_once(
        bypass,
        "GET",
        "/uplink/self/components/1/instances/1",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "data" => %{
                "attributes" => @component_instance_attributes
              }
            })
          )
        end
      )

      Bypass.expect_once(
        bypass,
        "PATCH",
        "/uplink/self/components/1/instances/1",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "data" => %{
                "attributes" => @component_instance_attributes
              }
            })
          )
        end
      )

      assert {:ok, _result} =
               perform_job(Instance.Modify, %{
                 component_id: "1",
                 variable_id: "1",
                 component_instance_id: "1",
                 arguments: %{"acl" => "private", "cors" => @cors_config}
               })
    end
  end
end
